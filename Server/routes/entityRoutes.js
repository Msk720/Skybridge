/**
 * Module: Routes
 * Purpose: Handles entity lifecycle operations.
 */
const express = require("express");
const { ObjectId } = require("mongodb");
const axios = require("axios");
const { getMongoClient } = require("../config/db");
const stripe = require("../config/stripe");
const {
    setCorsHeaders,
    verifyToken,
    hashDeliveryQrToken,
    toStripeCents,
    getStripeConnectReturnUrl,
    getStripeConnectCountry,
    getStripeCurrency,
    getOrderIdFromMetadata,
    buildProfileStats,
    moneyFromStripeAmount,
    safeObjectIdString,
    statusHistoryEntry,
    notificationRelatedId,
    createNotification,
    createNotifications,
    normalizeNotification,
    hasBuyerRatingDecision,
    isInactiveEntity,
    expireRelatedOffers,
    expireOffersWithUnavailableLinks,
    normalizeDateOnly,
    inactivateOverdueOrders,
    cleanupRatingDocuments,
    refreshTravelerRatingSummary,
    normalizeObjectId,
    getPaymentIdFromMetadata,
    ensureStripeConnectForUser,
    withAuthAndDb,
} = require("../utils/appUtils");

const updateEntityStatus = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        const { collection, id, status } = req.body;

        if (!collection || !id || !status) {
            return res.status(400).json({ error: "Missing params" });
        }

        if (collection !== "offers" && collection !== "orders") {
            return res.status(403).json({ error: "Invalid collection" });
        }

        if (!ObjectId.isValid(id)) {
            return res.status(400).json({ error: "Invalid id" });
        }

        const now = new Date();
        const oid = new ObjectId(id);

        if (collection === "orders") {
            const orders = db.collection("orders");
            const payments = db.collection("payments");
            const order = await orders.findOne({ _id: oid });

            if (!order) {
                return res.status(404).json({ error: "Order not found" });
            }

            const setData = {
                status,
                updatedAt: now,
            };

            const historyNote = status === "InTransit"
                ? "Traveler confirmed pickup"
                : status === "Inactive"
                    ? "Buyer cancelled order before pickup"
                    : "Order status updated";

            if (status === "InTransit") {
                if (order.travelerUid !== user.uid || order.status !== "Placed") {
                    return res.status(403).json({ error: "Unauthorized order status update" });
                }

                setData.pickupConfirmedAt = now;
                setData.travelerPickupConfirmedAt = now;
            } else if (status === "Inactive") {
                if (order.buyerUid !== user.uid || order.status !== "Placed") {
                    return res.status(403).json({ error: "Unauthorized order cancellation" });
                }

                const paymentId = normalizeObjectId(order.paymentId);
                const payment = paymentId
                    ? await payments.findOne({ _id: paymentId })
                    : null;

                if (!payment) {
                    return res.status(400).json({
                        error: "Payment record not found. Please contact support.",
                    });
                }

                if (payment.travelerPaymentStatus === "RELEASED" || payment.stripeTransferId) {
                    return res.status(409).json({
                        error: "This order cannot be cancelled because traveler payment has already been released.",
                    });
                }

                let refund = null;
                const alreadyRefunded = payment.paymentStatus === "REFUNDED" || payment.refundStatus === "SUCCEEDED";

                if (!alreadyRefunded) {
                    if (!payment.paymentIntentId) {
                        return res.status(400).json({
                            error: "Payment reference missing. Please contact support.",
                        });
                    }

                    try {
                        refund = await stripe.refunds.create({
                            payment_intent: payment.paymentIntentId,
                            reason: "requested_by_customer",
                            metadata: {
                                orderId: order._id.toString(),
                                paymentId: payment._id.toString(),
                                cancelledBy: user.uid,
                            },
                        });
                    } catch (err) {
                        console.error("Stripe refund error:", err);
                        return res.status(500).json({
                            error: err.message || "Refund failed. Please try again or contact support.",
                        });
                    }

                    await payments.updateOne(
                        { _id: payment._id },
                        {
                            $set: {
                                paymentStatus: "REFUNDED",
                                refundStatus: refund.status || "SUCCEEDED",
                                refundId: refund.id,
                                refundAmount: moneyFromStripeAmount(refund.amount),
                                refundCurrency: refund.currency || getStripeCurrency(),
                                refundedAt: now,
                                refundReason: "buyer_cancelled_before_pickup",
                                travelerPaymentStatus: "CANCELLED",
                                updatedAt: now,
                            },
                        }
                    );
                }

                setData.cancelledAt = now;
                setData.cancelledBy = user.uid;
                setData.cancellationReason = "buyer_cancelled_before_pickup";

                await Promise.all([
                    order.itemId
                        ? db.collection("items").updateOne(
                            { _id: order.itemId, bookedOrderId: order._id },
                            {
                                $set: {
                                    status: "Active",
                                    updatedAt: now,
                                },
                                $unset: {
                                    bookedOrderId: "",
                                    bookedAt: "",
                                },
                                $push: {
                                    statusHistory: statusHistoryEntry(
                                        "Active",
                                        user.uid,
                                        "Shipment reopened after buyer cancellation"
                                    ),
                                },
                            }
                        )
                        : Promise.resolve(),
                    order.tripId
                        ? db.collection("trips").updateOne(
                            { _id: order.tripId, bookedOrderId: order._id },
                            {
                                $set: {
                                    status: "Active",
                                    stat: "Active",
                                    updatedAt: now,
                                },
                                $unset: {
                                    bookedOrderId: "",
                                    bookedAt: "",
                                },
                                $push: {
                                    statusHistory: statusHistoryEntry(
                                        "Active",
                                        user.uid,
                                        "Trip reopened after buyer cancellation"
                                    ),
                                },
                            }
                        )
                        : Promise.resolve(),
                    payment.offerId
                        ? db.collection("offers").updateOne(
                            { _id: payment.offerId },
                            {
                                $set: {
                                    status: "Cancelled",
                                    updatedAt: now,
                                },
                                $push: {
                                    statusHistory: statusHistoryEntry(
                                        "Cancelled",
                                        user.uid,
                                        "Order cancelled and buyer refund initiated"
                                    ),
                                },
                            }
                        )
                        : Promise.resolve(),
                ]);
            }

            await orders.updateOne(
                { _id: oid },
                {
                    $set: setData,
                    $push: {
                        statusHistory: statusHistoryEntry(status, user.uid, historyNote),
                    },
                }
            );

            if (status === "InTransit") {
                await createNotification(db, {
                    userId: order.buyerUid,
                    type: "ORDER_PICKED",
                    title: "Shipment Picked Up",
                    message: "Your shipment has been picked up by the traveler.",
                    relatedType: "order",
                    relatedId: order._id,
                    actorUid: user.uid,
                    targetRole: "buyer",
                });
            } else if (status === "Inactive") {
                await createNotifications(db, [
                    {
                        userId: order.travelerUid,
                        type: "ORDER_CANCELLED",
                        title: "Order Cancelled",
                        message: "The buyer cancelled this order before pickup.",
                        relatedType: "order",
                        relatedId: order._id,
                        actorUid: user.uid,
                        targetRole: "traveler",
                    },
                    {
                        userId: order.buyerUid,
                        type: "ORDER_CANCELLED",
                        title: "Order Cancelled",
                        message: "Your order was cancelled and refund processing has started.",
                        relatedType: "order",
                        relatedId: order._id,
                        actorUid: user.uid,
                        targetRole: "buyer",
                    },
                ]);
            }

            return res.json({ success: true });
        }

        const existingDoc = await db.collection(collection).findOne({ _id: oid });

        if (!existingDoc) {
            return res.status(404).json({ error: "Record not found" });
        }

        await db.collection(collection).updateOne(
            { _id: oid },
            {
                $set: {
                    status,
                    updatedAt: now,
                },
                $push: {
                    statusHistory: statusHistoryEntry(status, user.uid, "Status updated"),
                },
            }
        );

        if (collection === "offers" && status === "Rejected") {
            await createNotification(db, {
                userId: existingDoc.travelerUid,
                type: "OFFER_REJECTED",
                title: "Offer Rejected",
                message: "Your offer was rejected by the buyer.",
                relatedType: "offer",
                relatedId: existingDoc._id,
                actorUid: user.uid,
                targetRole: "traveler",
            });
        } else if (collection === "offers" && status === "Accepted") {
            await createNotification(db, {
                userId: existingDoc.travelerUid,
                type: "OFFER_ACCEPTED",
                title: "Offer Accepted",
                message: "Your offer was accepted by the buyer.",
                relatedType: "offer",
                relatedId: existingDoc._id,
                actorUid: user.uid,
                targetRole: "traveler",
            });
        }

        return res.json({ success: true });
    })
);





const router = express.Router();

router.all("/updateEntityStatus", updateEntityStatus);

module.exports = router;

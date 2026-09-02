/**
 * Module: Routes
 * Purpose: Handles reusable order creation, listing, cancellation, and status updates.
 */
const express = require("express");
const { ObjectId } = require("mongodb");
const axios = require("axios");
const { getMongoClient } = require("../config/db");
const stripe = require("../config/stripe");
const Order = require("../models/Order");
const { protectTrustedSession: protect, requirePlatformAccess: requireRole } = require("../middleware/authMiddleware");
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


function orderObjectId(value) {
    return ObjectId.isValid(value) ? new ObjectId(value) : null;
}

function normalizeOrderStatus(status) {
    const raw = String(status || "pending").toLowerCase();
    if (["cancelled", "canceled", "rejected", "expired"].includes(raw)) return "cancelled";
    if (["confirmed", "accepted", "intransit", "in_transit", "received", "completed", "delivered", "paid"].includes(raw)) return "confirmed";
    return "pending";
}

function mapDashboardStatusToOrderStatus(status) {
    const raw = String(status || "").toLowerCase();
    if (raw === "cancelled" || raw === "canceled") return "Cancelled";
    if (raw === "confirmed") return "InTransit";
    return "Placed";
}

function objectIdString(value) {
    if (!value) return "";
    return value.toString ? value.toString() : String(value);
}

function formatOrderResponse(raw = {}) {
    const id = objectIdString(raw._id || raw.id);
    const item = raw.item || raw.product || {};
    const trip = raw.trip || {};
    const buyer = raw.buyer || raw.user || {};
    const traveler = raw.traveler || {};
    const payment = raw.payment || {};

    const productTitle = raw.itemName || item.name || item.title || raw.productName || "Product Order";
    const productPrice = Number(item.price || raw.itemPrice || raw.price || 0);
    const totalPrice = Number(raw.totalPrice || raw.totalAmount || raw.reward || payment.paymentAmount || productPrice || 0);
    const fromCity = raw.fromCity || trip.fromCity || "";
    const toCity = raw.toCity || trip.toCity || "";
    const fromCountry = raw.fromCountry || trip.fromCountry || "";
    const toCountry = raw.toCountry || trip.toCountry || "";
    const route = [fromCity || fromCountry, toCity || toCountry].filter(Boolean).join(" → ") || item.category || "Delivery";

    return {
        ...raw,
        _id: id,
        id,
        status: normalizeOrderStatus(raw.status),
        originalStatus: raw.status || "Placed",
        totalPrice,
        quantity: Number(raw.numGuests || item.quantity || raw.quantity || 1),
        paymentMethod: raw.paymentMethod || payment.provider || payment.paymentMethod || "bank_transfer",
        orderDate: raw.travelDate || raw.departureDate || trip.departureDate || raw.createdAt,
        deliveryRoute: route,
        buyerName: buyer.name || raw.buyerName || "",
        buyerEmail: buyer.email || raw.buyerEmail || "",
        buyerPhone: buyer.phone || raw.buyerPhone || "",
        account: {
            _id: raw.buyerUid || buyer.userId || buyer.uid || "",
            name: buyer.name || raw.buyerName || "Buyer",
            email: buyer.email || raw.buyerEmail || "",
        },
        traveler: {
            _id: raw.travelerUid || traveler.userId || traveler.uid || "",
            name: traveler.name || raw.travelerName || "Traveler",
            email: traveler.email || raw.travelerEmail || "",
        },
        product: {
            _id: objectIdString(raw.itemId || item._id || item.id),
            title: productTitle,
            name: productTitle,
            category: route,
            price: productPrice,
            imageUrl: raw.itemImage || item.image || item.imageUrl || "",
        },
    };
}

function duplicateOrderKey(order = {}) {
    const payment = order.payment || {};
    const paymentKey = payment.paymentIntentId || payment.paymentReference || order.paymentIntentId || order.paymentReference;
    if (paymentKey) return `payment:${paymentKey}`;

    const offerKey = objectIdString(order.offerId);
    if (offerKey) return `offer:${offerKey}`;

    const logicalKey = [
        objectIdString(order.itemId),
        objectIdString(order.tripId),
        order.buyerUid || "",
        order.travelerUid || "",
    ].join("|");

    return logicalKey.replace(/\|/g, "") ? `logical:${logicalKey}` : `order:${objectIdString(order._id || order.id)}`;
}

function dedupeOrderDocs(orders = []) {
    const seen = new Set();
    return orders.filter((order) => {
        const key = duplicateOrderKey(order);
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
    });
}

async function ensureOrderIdempotencyIndexes(db) {
    if (ensureOrderIdempotencyIndexes.done) return;

    try {
        await Promise.all([
            db.collection("orders").createIndex(
                { offerId: 1 },
                { unique: true, sparse: true, name: "uniq_orders_offerId" }
            ),
            db.collection("payments").createIndex(
                { paymentIntentId: 1 },
                { unique: true, sparse: true, name: "uniq_payments_paymentIntentId" }
            ),
        ]);
        ensureOrderIdempotencyIndexes.done = true;
    } catch (error) {
        console.warn("Order idempotency index warning:", error.message);
    }
}

async function sendExistingOrderResponse(db, res, { orderId, paymentId, paymentIntentId, sessionId }) {
    const orderObjectIdValue = normalizeObjectId(orderId);
    let order = orderObjectIdValue
        ? await db.collection("orders").findOne({ _id: orderObjectIdValue })
        : null;

    let payment = null;
    const paymentObjectIdValue = normalizeObjectId(paymentId);

    if (paymentObjectIdValue) {
        payment = await db.collection("payments").findOne({ _id: paymentObjectIdValue });
    }

    if (!payment && paymentIntentId) {
        payment = await db.collection("payments").findOne({ paymentIntentId });
    }

    if (!payment && sessionId) {
        payment = await db.collection("payments").findOne({ paymentSessionId: sessionId });
    }

    if (!order && payment?.orderId) {
        const paymentOrderObjectId = normalizeObjectId(payment.orderId);
        order = paymentOrderObjectId
            ? await db.collection("orders").findOne({ _id: paymentOrderObjectId })
            : null;
    }

    return res.json({
        success: true,
        orderId: objectIdString(order?._id || orderId || payment?.orderId),
        paymentId: objectIdString(payment?._id || paymentId || order?.paymentId),
        alreadyExists: true,
    });
}

async function getOrdersWithDetails(match = {}) {
    return Order.aggregate([
        { $match: match },
        { $lookup: { from: "items", localField: "itemId", foreignField: "_id", as: "item" } },
        { $unwind: { path: "$item", preserveNullAndEmptyArrays: true } },
        { $lookup: { from: "Products", localField: "productId", foreignField: "_id", as: "product" } },
        { $unwind: { path: "$product", preserveNullAndEmptyArrays: true } },
        { $lookup: { from: "trips", localField: "tripId", foreignField: "_id", as: "trip" } },
        { $unwind: { path: "$trip", preserveNullAndEmptyArrays: true } },
        { $lookup: { from: "profiles", localField: "buyerUid", foreignField: "userId", as: "buyer" } },
        { $unwind: { path: "$buyer", preserveNullAndEmptyArrays: true } },
        { $lookup: { from: "profiles", localField: "travelerUid", foreignField: "userId", as: "traveler" } },
        { $unwind: { path: "$traveler", preserveNullAndEmptyArrays: true } },
        { $lookup: { from: "payments", localField: "paymentId", foreignField: "_id", as: "payment" } },
        { $unwind: { path: "$payment", preserveNullAndEmptyArrays: true } },
        { $addFields: {
            itemName: { $ifNull: ["$item.name", "$product.name"] },
            itemImage: { $ifNull: ["$item.image", "$product.image"] },
            fromCity: "$trip.fromCity",
            toCity: "$trip.toCity",
            fromCountry: "$trip.fromCountry",
            toCountry: "$trip.toCountry",
            departureDate: { $ifNull: ["$trip.departureDate", { $ifNull: ["$departureDate", "$item.date"] }] },
            deliveryDate: { $ifNull: ["$item.date", { $ifNull: ["$deliveryDate", "$departureDate"] }] },
        } },
        { $sort: { createdAt: -1, _id: -1 } },
    ]);
}

const createOrder = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        let { offerId, paymentIntentId, sessionId } = req.body;
        let checkoutSession = null;
        let paymentIntent = null;
        let paymentVerificationSource = "payment_intent";
        let orderCreationLockId = null;
        let lockedOfferId = null;

        if (sessionId) {
            checkoutSession = await stripe.checkout.sessions.retrieve(sessionId);

            if (checkoutSession.payment_status !== "paid") {
                return res.status(400).json({ error: "Payment not completed" });
            }

            offerId = checkoutSession.metadata.offerId;
            paymentIntentId = checkoutSession.payment_intent;
            paymentVerificationSource = "checkout_session";
        }

        if (!offerId || !paymentIntentId) {
            return res.status(400).json({
                error: "Missing offerId or payment data",
            });
        }

        if (!ObjectId.isValid(offerId)) {
            return res.status(400).json({ error: "Invalid offerId" });
        }

        await ensureOrderIdempotencyIndexes(db);

        const paymentsCollection = db.collection("payments");
        const ordersCollection = db.collection("orders");
        const offersCollection = db.collection("offers");
        const paymentLookup = sessionId
            ? { $or: [{ paymentIntentId }, { paymentSessionId: sessionId }] }
            : { paymentIntentId };

        const existingPayment = await paymentsCollection.findOne(paymentLookup);

        if (existingPayment?.orderId) {
            return sendExistingOrderResponse(db, res, {
                orderId: existingPayment.orderId,
                paymentId: existingPayment._id,
                paymentIntentId,
                sessionId,
            });
        }

        paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

        if (!paymentIntent || paymentIntent.status !== "succeeded") {
            return res.status(400).json({ error: "Payment was not verified as succeeded" });
        }

        if (paymentIntent.metadata?.offerId && paymentIntent.metadata.offerId !== offerId) {
            return res.status(403).json({ error: "Payment does not match this offer" });
        }

        const offer = await offersCollection.findOne({
            _id: new ObjectId(offerId),
            buyerUid: user.uid,
        });

        if (!offer) {
            return res.status(403).json({ error: "Offer not found or unauthorized" });
        }

        if (offer.orderId) {
            return sendExistingOrderResponse(db, res, {
                orderId: offer.orderId,
                paymentId: existingPayment?._id || offer.paymentId,
                paymentIntentId,
                sessionId,
            });
        }

        const existingOrderForOffer = await ordersCollection.findOne({ offerId: offer._id });
        if (existingOrderForOffer) {
            await offersCollection.updateOne(
                { _id: offer._id },
                { $set: { orderId: existingOrderForOffer._id, status: "Accepted", updatedAt: new Date() } }
            );

            return sendExistingOrderResponse(db, res, {
                orderId: existingOrderForOffer._id,
                paymentId: existingOrderForOffer.paymentId,
                paymentIntentId,
                sessionId,
            });
        }

        const now = new Date();
        const staleLockBefore = new Date(now.getTime() - 2 * 60 * 1000);
        orderCreationLockId = `${now.getTime()}-${Math.random().toString(16).slice(2)}`;
        lockedOfferId = offer._id;

        const claimResult = await offersCollection.updateOne(
            {
                _id: offer._id,
                buyerUid: user.uid,
                $and: [
                    { $or: [{ orderId: { $exists: false } }, { orderId: null }] },
                    {
                        $or: [
                            { orderCreationLockId: { $exists: false } },
                            { orderCreationLockId: null },
                            { orderCreationStartedAt: { $lt: staleLockBefore } },
                        ],
                    },
                ],
            },
            {
                $set: {
                    orderCreationLockId,
                    orderCreationStartedAt: now,
                    updatedAt: now,
                },
            }
        );

        if (claimResult.modifiedCount === 0) {
            for (let attempt = 0; attempt < 6; attempt += 1) {
                await new Promise((resolve) => setTimeout(resolve, 300));

                const latestOffer = await offersCollection.findOne({ _id: offer._id });
                if (latestOffer?.orderId) {
                    return sendExistingOrderResponse(db, res, {
                        orderId: latestOffer.orderId,
                        paymentId: existingPayment?._id || latestOffer.paymentId,
                        paymentIntentId,
                        sessionId,
                    });
                }

                const existingDuringLock = await ordersCollection.findOne({ offerId: offer._id });
                if (existingDuringLock) {
                    return sendExistingOrderResponse(db, res, {
                        orderId: existingDuringLock._id,
                        paymentId: existingDuringLock.paymentId,
                        paymentIntentId,
                        sessionId,
                    });
                }
            }

            return res.status(409).json({
                error: "Order is already being created. Please refresh My Orders.",
                processing: true,
            });
        }

        try {
            const tripObjectId = normalizeObjectId(offer.tripId);
            const itemObjectId = normalizeObjectId(offer.itemId);
            const [offerTrip, offerItem] = await Promise.all([
                tripObjectId ? db.collection("trips").findOne({ _id: tripObjectId }) : Promise.resolve(null),
                itemObjectId ? db.collection("items").findOne({ _id: itemObjectId }) : Promise.resolve(null),
            ]);
            const orderDepartureDate = offerTrip?.departureDate || offerTrip?.date || offer.departureDate || offerItem?.date || null;
            const orderDeliveryDate = offerItem?.date || offerItem?.deliveryDate || offer.deliveryDate || offer.departureDate || orderDepartureDate || null;

            const paymentAmount = moneyFromStripeAmount(
                paymentIntent.amount_received || checkoutSession?.amount_total
            );
            const paymentCurrency = paymentIntent.currency || checkoutSession?.currency || getStripeCurrency();
            const stripeChargeId = typeof paymentIntent.latest_charge === "string"
                ? paymentIntent.latest_charge
                : paymentIntent.latest_charge?.id || null;

            const paymentDoc = {
                orderId: null,
                offerId: offer._id,
                buyerUid: offer.buyerUid,
                travelerUid: offer.travelerUid,
                itemId: offer.itemId,
                tripId: offer.tripId,
                provider: "stripe",
                type: "ORDER_PAYMENT",
                paymentReference: paymentIntentId,
                paymentIntentId,
                stripeChargeId,
                stripeLatestCharge: stripeChargeId,
                paymentSessionId: sessionId || existingPayment?.paymentSessionId || null,
                paymentStatus: "PAID",
                paymentGatewayStatus: paymentIntent.status,
                paymentAmount,
                paymentCurrency,
                paymentVerificationSource,
                paymentVerifiedAt: now,
                travelerPaymentStatus: "PENDING",
                paymentMetadata: {
                    offerId,
                    buyerUid: user.uid,
                    travelerUid: offer.travelerUid,
                    itemId: safeObjectIdString(offer.itemId),
                    tripId: safeObjectIdString(offer.tripId),
                    stripePaymentMethod: paymentIntent.payment_method || null,
                    stripeLatestCharge: stripeChargeId,
                },
                createdAt: existingPayment?.createdAt || now,
                updatedAt: now,
            };

            let paymentId = existingPayment?._id || null;

            if (paymentId) {
                await paymentsCollection.updateOne(
                    { _id: paymentId },
                    {
                        $set: {
                            ...paymentDoc,
                            orderId: null,
                            updatedAt: now,
                        },
                    }
                );
            } else {
                try {
                    const paymentResult = await paymentsCollection.insertOne(paymentDoc);
                    paymentId = paymentResult.insertedId;
                } catch (error) {
                    if (error.code === 11000) {
                        const duplicatePayment = await paymentsCollection.findOne({ paymentIntentId });
                        if (duplicatePayment?.orderId) {
                            return sendExistingOrderResponse(db, res, {
                                orderId: duplicatePayment.orderId,
                                paymentId: duplicatePayment._id,
                                paymentIntentId,
                                sessionId,
                            });
                        }

                        if (duplicatePayment?._id) {
                            paymentId = duplicatePayment._id;
                            await paymentsCollection.updateOne(
                                { _id: paymentId },
                                { $set: { ...paymentDoc, orderId: null, createdAt: duplicatePayment.createdAt || now, updatedAt: now } }
                            );
                        } else {
                            throw error;
                        }
                    } else {
                        throw error;
                    }
                }
            }

            const orderDoc = {
                offerId: offer._id,
                tripId: offer.tripId,
                itemId: offer.itemId,
                reward: Number(offer.offeredReward),
                totalAmount: Number(offer.totalAmount),
                travelerUid: offer.travelerUid,
                buyerUid: offer.buyerUid,
                departureDate: orderDepartureDate,
                deliveryDate: orderDeliveryDate,
                status: "Placed",
                paymentId,
                paymentIntentId,
                paymentSessionId: sessionId || null,
                paidAt: now,
                createdAt: now,
                updatedAt: now,
                statusHistory: [
                    statusHistoryEntry("Placed", user.uid, "Order created after backend payment verification"),
                ],
            };

            let orderId;
            try {
                const orderResult = await ordersCollection.insertOne(orderDoc);
                orderId = orderResult.insertedId;
            } catch (error) {
                if (error.code === 11000) {
                    const duplicateOrder = await ordersCollection.findOne({ offerId: offer._id });
                    if (duplicateOrder) {
                        return sendExistingOrderResponse(db, res, {
                            orderId: duplicateOrder._id,
                            paymentId: duplicateOrder.paymentId || paymentId,
                            paymentIntentId,
                            sessionId,
                        });
                    }
                }
                throw error;
            }

            await paymentsCollection.updateOne(
                { _id: paymentId },
                {
                    $set: {
                        orderId,
                        updatedAt: now,
                    },
                }
            );

            await offersCollection.updateOne(
                { _id: offer._id, orderCreationLockId },
                {
                    $set: {
                        status: "Accepted",
                        orderId,
                        paymentId,
                        updatedAt: now,
                    },
                    $unset: {
                        orderCreationLockId: "",
                        orderCreationStartedAt: "",
                    },
                    $push: {
                        statusHistory: statusHistoryEntry("Accepted", user.uid, "Offer accepted after payment"),
                    },
                }
            );

            await Promise.all([
                offer.itemId
                    ? db.collection("items").updateOne(
                        { _id: offer.itemId },
                        {
                            $set: {
                                status: "Inactive",
                                bookedOrderId: orderId,
                                bookedAt: now,
                                updatedAt: now,
                            },
                            $push: {
                                statusHistory: statusHistoryEntry(
                                    "Inactive",
                                    user.uid,
                                    "Shipment booked after order placement"
                                ),
                            },
                        }
                    )
                    : Promise.resolve(),
                offer.tripId
                    ? db.collection("trips").updateOne(
                        { _id: offer.tripId },
                        {
                            $set: {
                                status: "Inactive",
                                stat: "Inactive",
                                bookedOrderId: orderId,
                                bookedAt: now,
                                updatedAt: now,
                            },
                            $push: {
                                statusHistory: statusHistoryEntry(
                                    "Inactive",
                                    user.uid,
                                    "Trip booked after order placement"
                                ),
                            },
                        }
                    )
                    : Promise.resolve(),
                offer.itemId
                    ? offersCollection.updateMany(
                        {
                            _id: { $ne: offer._id },
                            itemId: offer.itemId,
                            status: "Pending",
                        },
                        {
                            $set: {
                                status: "Closed",
                                closedReason: "Shipment booked by another order",
                                updatedAt: now,
                            },
                            $push: {
                                statusHistory: statusHistoryEntry(
                                    "Closed",
                                    user.uid,
                                    "Shipment booked by another order"
                                ),
                            },
                        }
                    )
                    : Promise.resolve(),
            ]);

            await createNotifications(db, [
                {
                    userId: offer.travelerUid,
                    type: "OFFER_ACCEPTED",
                    title: "Offer Accepted",
                    message: "Your offer was accepted and the order has been placed.",
                    relatedType: "order",
                    relatedId: orderId,
                    actorUid: user.uid,
                    targetRole: "traveler",
                },
                {
                    userId: offer.buyerUid,
                    type: "ORDER_PLACED",
                    title: "Order Placed",
                    message: "Your payment was received and the order has been placed.",
                    relatedType: "order",
                    relatedId: orderId,
                    actorUid: user.uid,
                    targetRole: "buyer",
                },
            ]);

            return res.json({
                success: true,
                orderId: orderId.toString(),
                paymentId: paymentId.toString(),
            });
        } catch (error) {
            if (orderCreationLockId && lockedOfferId) {
                await offersCollection.updateOne(
                    { _id: lockedOfferId, orderCreationLockId },
                    {
                        $unset: {
                            orderCreationLockId: "",
                            orderCreationStartedAt: "",
                        },
                    }
                );
            }
            throw error;
        }
    })
);


// ================= STRIPE CONNECT: TRAVELER ONBOARDING =================


const router = express.Router();

router.all("/createOrder", createOrder);

router.get("/my", protect, async (req, res) => {
    try {
        const uid = req.user?.userId || req.user?.uid;
        const orders = await getOrdersWithDetails({ $or: [{ buyerUid: uid }, { travelerUid: uid }] });
        return res.json(dedupeOrderDocs(orders).map(formatOrderResponse));
    } catch (error) {
        console.error("My orders error:", error.message);
        return res.status(500).json({ message: "Server error" });
    }
});

router.get("/", protect, requireRole, async (req, res) => {
    try {
        const status = req.query.status ? String(req.query.status).toLowerCase() : null;
        const search = (req.query.search || "").trim();
        const match = {};

        if (status && status !== "all") {
            if (status === "confirmed") {
                match.status = { $in: ["Accepted", "InTransit", "Received", "Completed", "Delivered"] };
            } else if (status === "pending") {
                match.status = { $in: ["Placed", "Pending", "pending"] };
            } else {
                match.status = mapDashboardStatusToOrderStatus(status);
            }
        }

        let orders = dedupeOrderDocs(await getOrdersWithDetails(match));
        let mapped = orders.map(formatOrderResponse);

        if (search) {
            const q = search.toLowerCase();
            mapped = mapped.filter((order) =>
                order.account?.name?.toLowerCase().includes(q) ||
                order.account?.email?.toLowerCase().includes(q) ||
                order.traveler?.name?.toLowerCase().includes(q) ||
                order.product?.title?.toLowerCase().includes(q) ||
                order.product?.category?.toLowerCase().includes(q) ||
                order.originalStatus?.toLowerCase().includes(q)
            );
        }

        return res.json(mapped);
    } catch (error) {
        console.error("All orders error:", error.message);
        return res.status(500).json({ message: "Server error" });
    }
});

router.put("/:id/cancel", protect, async (req, res) => {
    try {
        const oid = orderObjectId(req.params.id);
        if (!oid) return res.status(400).json({ message: "Invalid order id" });

        const uid = req.user?.userId || req.user?.uid;
        const order = await Order.findOne({ _id: oid, $or: [{ buyerUid: uid }, { travelerUid: uid }] });
        if (!order) return res.status(404).json({ message: "Order not found" });

        order.status = "Cancelled";
        order.updatedAt = new Date();
        order.statusHistory = [
            ...(Array.isArray(order.statusHistory) ? order.statusHistory : []),
            { status: "Cancelled", by: uid, note: "Cancelled from dashboard", at: new Date() },
        ];
        await order.save();

        const [updated] = await getOrdersWithDetails({ _id: oid });
        return res.json(formatOrderResponse(updated || order));
    } catch (error) {
        console.error("Cancel order error:", error.message);
        return res.status(500).json({ message: "Server error" });
    }
});

router.put("/:id/status", protect, requireRole, async (req, res) => {
    try {
        const oid = orderObjectId(req.params.id);
        if (!oid) return res.status(400).json({ message: "Invalid order id" });

        const { status } = req.body;
        const allowed = ["pending", "confirmed", "cancelled"];
        if (!allowed.includes(String(status || "").toLowerCase())) {
            return res.status(400).json({ message: "Invalid status" });
        }

        const orderStatus = mapDashboardStatusToOrderStatus(status);
        const actorUid = req.user?.userId || req.user?.uid || req.user?._id;

        const order = await Order.findByIdAndUpdate(
            oid,
            {
                $set: { status: orderStatus, updatedAt: new Date() },
                $push: { statusHistory: { status: orderStatus, by: actorUid, note: "Updated from dashboard", at: new Date() } },
            },
            { new: true }
        );

        if (!order) return res.status(404).json({ message: "Order not found" });

        const [updated] = await getOrdersWithDetails({ _id: oid });
        return res.json(formatOrderResponse(updated || order));
    } catch (error) {
        console.error("Update order status error:", error.message);
        return res.status(500).json({ message: "Server error" });
    }
});

module.exports = router;

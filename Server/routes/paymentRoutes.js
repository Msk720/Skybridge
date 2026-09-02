/**
 * Module: Routes
 * Purpose: Handles Stripe payment, webhook, and delivery payment flows.
 */
/* Naming note: some handlers in this file do more than payment verification, including order completion and payout release. Review before renaming functions. */
const express = require("express");
const { ObjectId } = require("mongodb");
const axios = require("axios");
const { getMongoClient } = require("../config/db");
const stripe = require("../config/stripe");
const crypto = require("crypto");
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
const {
    DISPUTE_WINDOW_MINUTES,
    getDisputeWindowLabel,
    getTravelerPaymentHoldStatus,
} = require("../utils/disputePaymentUtils");

function getCheckoutAppOrigin(req) {
    const candidates = [
        req.body?.appOrigin,
        req.body?.returnOrigin,
        req.headers.origin,
        process.env.CLIENT_APP_URL,
        process.env.FRONTEND_URL,
    ];

    for (const candidate of candidates) {
        if (!candidate) continue;
        try {
            const parsed = new URL(String(candidate));
            if (["http:", "https:"].includes(parsed.protocol)) return parsed.origin;
        } catch (_) {}
    }

    return "http://localhost:3000";
}


const createStripeConnectAccountLink = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        if (!process.env.STRIPE_SECRET) {
            return res.status(500).json({ error: "Stripe secret key is not configured" });
        }

        const profiles = db.collection("profiles");
        const stripeConnectCollection = db.collection("stripeconnect");
        const { profile, stripeConnect } = await ensureStripeConnectForUser(db, user);

        let activeStripeConnect = stripeConnect;
        let stripeAccountId = activeStripeConnect?.stripeAccountId;

        try {
            if (!stripeAccountId) {
                const account = await stripe.accounts.create({
                    type: "express",
                    country: getStripeConnectCountry(),
                    email: profile.email || user.email || undefined,
                    capabilities: {
                        transfers: { requested: true },
                    },
                    business_type: "individual",
                    metadata: {
                        userId: user.uid,
                        source: "skybridge_traveler_profile",
                    },
                });

                const now = new Date();
                const accountDoc = {
                    userId: user.uid,
                    provider: "stripe",
                    connectType: "express",
                    stripeAccountId: account.id,
                    stripeDetailsSubmitted: !!account.details_submitted,
                    stripePayoutsEnabled: !!account.payouts_enabled,
                    stripeChargesEnabled: !!account.charges_enabled,
                    stripeCurrentlyDue: account.requirements?.currently_due || [],
                    stripePastDue: account.requirements?.past_due || [],
                    stripeDisabledReason: account.requirements?.disabled_reason || null,
                    stripeConnectCountry: getStripeConnectCountry(),
                    createdAt: now,
                    updatedAt: now,
                };

                const result = await stripeConnectCollection.insertOne(accountDoc);
                activeStripeConnect = {
                    ...accountDoc,
                    _id: result.insertedId,
                };

                await profiles.updateOne(
                    { userId: user.uid },
                    {
                        $set: {
                            stripeConnectId: result.insertedId,
                            updatedAt: now,
                        },
                    },
                    { upsert: true }
                );

                stripeAccountId = account.id;
            }

            const returnUrl = getStripeConnectReturnUrl();

            const accountLink = await stripe.accountLinks.create({
                account: stripeAccountId,
                refresh_url: returnUrl,
                return_url: returnUrl,
                type: "account_onboarding",
            });

            return res.status(200).json({
                success: true,
                url: accountLink.url,
                stripeAccountId,
                stripeConnectId: activeStripeConnect?._id?.toString() || "",
            });
        } catch (err) {
            console.error("createStripeConnectAccountLink error:", err);
            return res.status(500).json({
                error: err.message || "Unable to create Stripe Connect onboarding link",
            });
        }
    })
);


const getStripeConnectAccountStatus = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (!["GET", "POST"].includes(req.method)) {
            return res.status(405).send("Only GET or POST allowed");
        }

        const { stripeConnect } = await ensureStripeConnectForUser(db, user);

        if (!stripeConnect || !stripeConnect.stripeAccountId) {
            return res.status(200).json({
                success: true,
                connected: false,
                detailsSubmitted: false,
                payoutsEnabled: false,
                chargesEnabled: false,
            });
        }

        try {
            const account = await stripe.accounts.retrieve(stripeConnect.stripeAccountId);
            const requirements = account.requirements || {};
            const now = new Date();

            const statusData = {
                stripeAccountId: account.id,
                stripeDetailsSubmitted: !!account.details_submitted,
                stripePayoutsEnabled: !!account.payouts_enabled,
                stripeChargesEnabled: !!account.charges_enabled,
                stripeCurrentlyDue: requirements.currently_due || [],
                stripePastDue: requirements.past_due || [],
                stripeDisabledReason: requirements.disabled_reason || null,
                stripeAccountStatusUpdatedAt: now,
                updatedAt: now,
            };

            await db.collection("stripeconnect").updateOne(
                { _id: stripeConnect._id },
                { $set: statusData }
            );

            return res.status(200).json({
                success: true,
                connected: true,
                stripeConnectId: stripeConnect._id.toString(),
                stripeAccountId: account.id,
                detailsSubmitted: statusData.stripeDetailsSubmitted,
                payoutsEnabled: statusData.stripePayoutsEnabled,
                chargesEnabled: statusData.stripeChargesEnabled,
                currentlyDue: statusData.stripeCurrentlyDue,
                pastDue: statusData.stripePastDue,
                disabledReason: statusData.stripeDisabledReason,
            });
        } catch (err) {
            console.error("getStripeConnectAccountStatus error:", err);
            return res.status(500).json({
                error: err.message || "Unable to refresh Stripe Connect status",
            });
        }
    })
);


const createStripeConnectDashboardLoginLink = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        const { stripeConnect } = await ensureStripeConnectForUser(db, user);

        if (!stripeConnect || !stripeConnect.stripeAccountId) {
            return res.status(400).json({
                error: "Stripe Connect account is not connected",
            });
        }

        try {
            const loginLink = await stripe.accounts.createLoginLink(
                stripeConnect.stripeAccountId
            );

            return res.status(200).json({
                success: true,
                url: loginLink.url,
            });
        } catch (err) {
            console.error("createStripeConnectDashboardLoginLink error:", err);
            return res.status(500).json({
                error: err.message || "Unable to create Stripe dashboard login link",
            });
        }
    })
);



// ================= DELIVERY QR: BUYER GENERATES QR =================

const createDeliveryQr = withAuthAndDb(
    async ({ req, res, db, user }) => {
        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        const { orderId } = req.body || {};

        if (!orderId || !ObjectId.isValid(orderId)) {
            return res.status(400).json({
                error: "Invalid or missing orderId",
            });
        }

        const order = await db.collection("orders").findOne({
            _id: new ObjectId(orderId),
            buyerUid: user.uid,
        });

        if (!order) {
            return res.status(404).json({
                error: "Order not found or unauthorized",
            });
        }

        if (order.status !== "InTransit") {
            return res.status(400).json({
                error: "Delivery QR can only be generated for InTransit orders",
            });
        }

        const token = crypto.randomBytes(32).toString("hex");
        const tokenHash = hashDeliveryQrToken(token);

        const qrTransactionId = crypto.randomUUID();
        const now = new Date();

        await db.collection("orders").updateOne(
            { _id: order._id },
            {
                $set: {
                    deliveryQrTransactionId: qrTransactionId,
                    deliveryQrTokenHash: tokenHash,
                    deliveryQrStatus: "ACTIVE",
                    deliveryQrCreatedAt: now,
                    deliveryQrCreatedBy: user.uid,
                    deliveryQrUsedAt: null,
                    updatedAt: now,
                },
            }
        );

        console.log("QR GENERATED", {
            orderId,
            qrTransactionId,
            buyerUid: user.uid,
        });

        return res.status(200).json({
            success: true,
            qrTransactionId,
            qrPayload: JSON.stringify({
                type: "delivery_verification",
                orderId,
                qrTransactionId,
                token,
            }),
        });
    }
);



// ================= DELIVERY QR: TRAVELER VERIFIES DELIVERY =================
const verifyDeliveryQr = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        const { orderId, token, qrTransactionId } = req.body || {};

        if (!orderId || !ObjectId.isValid(orderId) || !token) {
            return res.status(400).json({ error: "Invalid or missing verification data" });
        }

        const tokenHash = hashDeliveryQrToken(token);
        const orders = db.collection("orders");
        const payments = db.collection("payments");

        const order = await orders.findOne({
            _id: new ObjectId(orderId),
            travelerUid: user.uid,
        });

        if (!order) {
            return res.status(404).json({ error: "Order not found or unauthorized" });
        }

        if (order.status !== "InTransit") {
            return res.status(400).json({
                error: "Only InTransit orders can be verified as received",
            });
        }

        if (!order.deliveryQrTokenHash || order.deliveryQrTokenHash !== tokenHash) {
            return res.status(403).json({ error: "Invalid delivery QR" });
        }

        if (order.deliveryQrTransactionId && qrTransactionId && order.deliveryQrTransactionId !== qrTransactionId) {
            return res.status(403).json({ error: "Invalid delivery QR transaction" });
        }

        const paymentObjectId = normalizeObjectId(order.paymentId);
        const payment = paymentObjectId
            ? await payments.findOne({ _id: paymentObjectId })
            : null;

        if (!payment) {
            return res.status(400).json({
                error: "Payment record not found for this order",
            });
        }

        if (payment.paymentStatus !== "PAID") {
            return res.status(400).json({
                error: "Order payment is not confirmed yet",
            });
        }

        if (payment.travelerPaymentStatus === "RELEASED" || payment.stripeTransferId) {
            return res.status(409).json({ error: "Traveler payment has already been released" });
        }

        const now = new Date();
        const disputeWindowEndsAt = new Date(now.getTime() + DISPUTE_WINDOW_MINUTES * 60 * 1000);

        const result = await orders.updateOne(
            {
                _id: order._id,
                travelerUid: user.uid,
                status: "InTransit",
            },
            {
                $set: {
                    status: "Received",
                    completedAt: now,
                    deliveryConfirmedAt: now,
                    deliveryQrUsedAt: now,
                    deliveryQrStatus: "USED",
                    deliveryQrUsedTokenHash: tokenHash,
                    deliveryVerifiedAt: now,
                    buyerConfirmedAt: now,
                    buyerConfirmationMethod: "DELIVERY_QR_PRESENTED",
                    buyerRatingPromptPending: true,
                    travelerConfirmedAt: now,
                    travelerConfirmationMethod: "DELIVERY_QR_SCAN",
                    disputeWindowStartedAt: now,
                    disputeWindowEndsAt,
                    disputeWindowMinutes: DISPUTE_WINDOW_MINUTES,
                    paymentReleaseEligibleAt: disputeWindowEndsAt,
                    paymentHoldReason: "DISPUTE_WINDOW",
                    paymentOutcome: "HOLDING_FOR_DISPUTE_WINDOW",
                    completionProof: {
                        method: "DELIVERY_QR",
                        qrTransactionId: order.deliveryQrTransactionId || qrTransactionId || null,
                        buyerUid: order.buyerUid,
                        travelerUid: user.uid,
                        verifiedBy: user.uid,
                        verifiedAt: now,
                        tokenHash,
                    },
                    updatedAt: now,
                },
                $push: {
                    statusHistory: statusHistoryEntry("Received", user.uid, `Delivery QR verified. Payment held for ${getDisputeWindowLabel()} dispute window.`),
                },
                $unset: {
                    deliveryQrTokenHash: "",
                },
            }
        );

        if (result.modifiedCount !== 1) {
            return res.status(409).json({
                error: "Order status could not be finalized. Please refresh orders.",
            });
        }

        await payments.updateOne(
            { _id: payment._id },
            {
                $set: {
                    travelerPaymentStatus: getTravelerPaymentHoldStatus(),
                    heldAfterDeliveryAt: now,
                    paymentReleaseEligibleAt: disputeWindowEndsAt,
                    paymentHoldReason: "DISPUTE_WINDOW",
                    paymentReleaseMethod: "AFTER_DISPUTE_WINDOW",
                    updatedAt: now,
                },
                $unset: {
                    travelerPaymentError: "",
                },
            }
        );

        await createNotifications(db, [
            {
                userId: order.buyerUid,
                type: "ORDER_RECEIVED",
                title: "Order Received",
                message: "Your order was marked as received.",
                relatedType: "order",
                relatedId: order._id,
                actorUid: user.uid,
                targetRole: "buyer",
            },
            {
                userId: order.travelerUid,
                type: "ORDER_RECEIVED",
                title: "Delivery Completed",
                message: `Delivery was completed. Payment will release after ${getDisputeWindowLabel()} if no dispute is filed.`,
                relatedType: "order",
                relatedId: order._id,
                actorUid: user.uid,
                targetRole: "traveler",
            },
        ]);

        return res.status(200).json({
            success: true,
            status: "Received",
            travelerPaymentStatus: getTravelerPaymentHoldStatus(),
            disputeWindowEndsAt,
        });
    })
);


const createPaymentIntentFromOffer = (
    withAuthAndDb(async ({ req, res, db, user }) => {

        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        const { offerId, appOrigin, returnOrigin } = req.body;

        const offer = await db.collection("offers").findOne({
            _id: new ObjectId(offerId),
            buyerUid: user.uid,
        })

        if (!offer) {
            return res.status(404).json({ error: "Offer not found" });
        }

        if (offer.orderId || String(offer.status || "").toLowerCase() === "accepted") {
            return res.status(409).json({
                error: "This offer already has an order. Please open My Orders.",
                orderId: offer.orderId ? offer.orderId.toString() : null,
            });
        }

        const originalAmount = Number(offer.totalAmount);
        const amountCents = Math.round(originalAmount * 100);


        const totalCents = Math.round(
            (amountCents + 30) / (1 - 0.029)
        );

        const stripeFeeCents = totalCents - amountCents;

        const paymentIntent = await stripe.paymentIntents.create({
            amount: totalCents,
            currency: "usd",
            automatic_payment_methods: { enabled: true },
            metadata: {
                offerId: String(offerId),
                buyerUid: user.uid,
                travelerUid: offer.travelerUid || "",
                itemId: safeObjectIdString(offer.itemId),
                tripId: safeObjectIdString(offer.tripId),
                originalAmount: String(originalAmount),
                stripeFee: String(stripeFeeCents / 100)
            },
        });

        return res.json({
            clientSecret: paymentIntent.client_secret,
            paymentIntentId: paymentIntent.id,
            originalAmount: originalAmount,
            stripeFee: stripeFeeCents / 100,
            total: totalCents / 100,
        });
    })
);

// ================= STRIPE WEBHOOK: MINIMUM FYP PAYMENT STATUS SYNC =================
const stripeWebhook = (async (req, res) => {
    if (req.method !== "POST") {
        return res.status(405).send("Only POST allowed");
    }

    let event;

    try {
        const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
        const signature = req.headers["stripe-signature"];

        if (webhookSecret && signature) {
            event = stripe.webhooks.constructEvent(
                req.rawBody,
                signature,
                webhookSecret
            );
        } else {
            event = req.body;
        }
    } catch (err) {
        console.error("stripeWebhook signature error:", err.message);
        return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    try {
        const client = await getMongoClient();
        const db = client.db("myDatabase");
        const now = new Date();

        const alreadyProcessed = await db.collection("stripeEvents").findOne({
            eventId: event.id,
        });

        if (alreadyProcessed) {
            return res.status(200).json({ received: true, duplicate: true });
        }

        await db.collection("stripeEvents").insertOne({
            eventId: event.id,
            type: event.type,
            stripeAccountId: event.account || null,
            createdAt: now,
            processedAt: null,
        });

        const data = event.data?.object || {};

        if (event.type === "payment_intent.succeeded") {
            await db.collection("payments").updateMany(
                { paymentIntentId: data.id },
                {
                    $set: {
                        paymentStatus: "PAID",
                        paymentGatewayStatus: data.status,
                        stripeChargeId: typeof data.latest_charge === "string" ? data.latest_charge : data.latest_charge?.id || null,
                        stripeLatestCharge: typeof data.latest_charge === "string" ? data.latest_charge : data.latest_charge?.id || null,
                        paymentWebhookVerifiedAt: now,
                        updatedAt: now,
                    },
                }
            );
        } else if (event.type === "payment_intent.payment_failed") {
            const failureMessage = data.last_payment_error?.message || "Payment failed";

            await db.collection("payments").updateMany(
                { paymentIntentId: data.id },
                {
                    $set: {
                        paymentStatus: "FAILED",
                        paymentGatewayStatus: data.status,
                        paymentFailedAt: now,
                        paymentFailureReason: failureMessage,
                        updatedAt: now,
                    },
                }
            );
        } else if (event.type === "account.updated") {
            await db.collection("stripeconnect").updateOne(
                { stripeAccountId: data.id },
                {
                    $set: {
                        stripeDetailsSubmitted: !!data.details_submitted,
                        stripePayoutsEnabled: !!data.payouts_enabled,
                        stripeChargesEnabled: !!data.charges_enabled,
                        stripeCurrentlyDue: data.requirements?.currently_due || [],
                        stripePastDue: data.requirements?.past_due || [],
                        stripeDisabledReason: data.requirements?.disabled_reason || null,
                        stripeAccountStatusUpdatedAt: now,
                        updatedAt: now,
                    },
                }
            );
        } else if (event.type === "transfer.created") {
            const paymentObjectId = getPaymentIdFromMetadata(data.metadata);
            const transferUpdate = {
                travelerPaymentStatus: "RELEASED",
                stripeTransferId: data.id,
                stripeTransferAmount: moneyFromStripeAmount(data.amount),
                stripeTransferCurrency: data.currency || getStripeCurrency(),
                stripeTransferWebhookAt: now,
                updatedAt: now,
            };

            if (paymentObjectId) {
                await db.collection("payments").updateOne(
                    { _id: paymentObjectId },
                    { $set: transferUpdate }
                );
            } else {
                await db.collection("payments").updateOne(
                    { stripeTransferId: data.id },
                    { $set: transferUpdate }
                );
            }
        } else if (event.type === "transfer.failed" || event.type === "transfer.reversed") {
            const paymentObjectId = getPaymentIdFromMetadata(data.metadata);
            const transferUpdate = {
                travelerPaymentStatus: "FAILED",
                travelerPaymentError: event.type,
                stripeTransferId: data.id,
                updatedAt: now,
            };

            if (paymentObjectId) {
                await db.collection("payments").updateOne(
                    { _id: paymentObjectId },
                    { $set: transferUpdate }
                );
            } else {
                await db.collection("payments").updateOne(
                    { stripeTransferId: data.id },
                    { $set: transferUpdate }
                );
            }
        } else if (event.type === "payout.paid" || event.type === "payout.failed") {
            if (event.account) {
                await db.collection("stripeconnect").updateOne(
                    { stripeAccountId: event.account },
                    {
                        $set: {
                            lastStripePayoutId: data.id,
                            lastStripePayoutStatus: data.status || event.type,
                            lastStripePayoutAmount: moneyFromStripeAmount(data.amount),
                            lastStripePayoutCurrency: data.currency || getStripeCurrency(),
                            lastStripePayoutAt: now,
                            updatedAt: now,
                        },
                    }
                );
            }
        }

        await db.collection("stripeEvents").updateOne(
            { eventId: event.id },
            {
                $set: {
                    processedAt: now,
                    processed: true,
                },
            }
        );

        return res.status(200).json({ received: true });
    } catch (err) {
        console.error("stripeWebhook processing error:", err);
        return res.status(500).json({ error: "Webhook processing failed" });
    }
});


// ========================================================================
//                          AUTO EXPIRE ENTITIES (PK TIME)
// ========================================================================

const createCheckoutSessionFromOffer = (
    withAuthAndDb(async ({ req, res, db, user }) => {

        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        const { offerId } = req.body;
        if (!offerId) {
            return res.status(400).json({ error: "Missing offerId" });
        }

        const offer = await db.collection("offers").findOne({
            _id: new ObjectId(offerId),
            buyerUid: user.uid,
        });

        if (!offer) {
            return res.status(404).json({ error: "Offer not found" });
        }

        if (offer.orderId || String(offer.status || "").toLowerCase() === "accepted") {
            return res.status(409).json({
                error: "This offer already has an order. Please open My Orders.",
                orderId: offer.orderId ? offer.orderId.toString() : null,
            });
        }

        const originalAmount = Number(offer.totalAmount);
        const amountCents = Math.round(originalAmount * 100);

        const totalCents = Math.round(
            (amountCents + 30) / (1 - 0.029)
        );

        const stripeFeeCents = totalCents - amountCents;



        const session = await stripe.checkout.sessions.create({
            mode: "payment",
            payment_method_types: ["card"],
            line_items: [
                {
                    price_data: {
                        currency: "usd",
                        product_data: {
                            name: "SkyBridge Order Payment",
                        },
                        unit_amount: totalCents,
                    },
                    quantity: 1,
                },
            ],
            metadata: {
                offerId: String(offerId),
                buyerUid: user.uid,
                travelerUid: offer.travelerUid || "",
                itemId: safeObjectIdString(offer.itemId),
                tripId: safeObjectIdString(offer.tripId),
                originalAmount: String(originalAmount),
                stripeFee: String(stripeFeeCents / 100),
            },
            success_url:
                `${getCheckoutAppOrigin(req)}/#/stripe?session_id={CHECKOUT_SESSION_ID}`,

            cancel_url:
                `${getCheckoutAppOrigin(req)}/#/stripe?cancel=true`,

        });

        return res.json({ url: session.url });
    })
);





const router = express.Router();

router.all("/createStripeConnectAccountLink", createStripeConnectAccountLink);
router.all("/getStripeConnectAccountStatus", getStripeConnectAccountStatus);
router.all("/createStripeConnectDashboardLoginLink", createStripeConnectDashboardLoginLink);
router.all("/createDeliveryQr", createDeliveryQr);
router.all("/verifyDeliveryQr", verifyDeliveryQr);
router.all("/createPaymentIntentFromOffer", createPaymentIntentFromOffer);
router.all("/stripeWebhook", stripeWebhook);
router.all("/createCheckoutSessionFromOffer", createCheckoutSessionFromOffer);

module.exports = router;

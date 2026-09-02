/**
 * Module: Routes
 * Purpose: Handles rating endpoints.
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

const submitTravelerRating = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        try {
            const { orderId, rating } = req.body || {};
            const numericRating = Number(rating);

            if (!orderId || !ObjectId.isValid(orderId)) {
                return res.status(400).json({ error: "Invalid order id" });
            }

            if (!Number.isFinite(numericRating) || numericRating < 1 || numericRating > 5) {
                return res.status(400).json({ error: "Rating must be between 1 and 5" });
            }

            const orders = db.collection("orders");
            const ratings = db.collection("ratings");
            const order = await orders.findOne({ _id: new ObjectId(orderId) });

            if (!order) {
                return res.status(404).json({ error: "Order not found" });
            }

            if (order.buyerUid !== user.uid) {
                return res.status(403).json({ error: "Only the buyer can rate this traveler" });
            }

            if (order.status !== "Received") {
                return res.status(400).json({ error: "Only received orders can be rated" });
            }

            if (hasBuyerRatingDecision(order)) {
                return res.status(409).json({ error: "Rating decision already saved" });
            }

            const existingDecision = await ratings.findOne({
                orderId: order._id,
                buyerUid: user.uid,
            });

            if (existingDecision) {
                return res.status(409).json({ error: "Rating decision already saved" });
            }

            const now = new Date();
            const ratingDoc = {
                orderId: order._id,
                buyerUid: order.buyerUid,
                travelerUid: order.travelerUid,
                rating: numericRating,
                status: "rated",
                createdAt: now,
            };

            const ratingResult = await ratings.insertOne(ratingDoc);
            const summary = await refreshTravelerRatingSummary(db, order.travelerUid);

            await orders.updateOne(
                { _id: order._id },
                {
                    $set: {
                        buyerRatingSubmitted: true,
                        buyerRatingSkipped: false,
                        buyerRatingStatus: "rated",
                        travelerRatingId: ratingResult.insertedId,
                        travelerRatingValue: numericRating,
                        travelerRatedAt: now,
                        updatedAt: now,
                    },
                    $unset: {
                        ratingSkippedAt: "",
                    },
                }
            );

            await createNotification(db, {
                userId: order.travelerUid,
                type: "RATING_RECEIVED",
                title: "New Rating Received",
                message: `You received ${numericRating.toFixed(1)} stars from a buyer.`,
                relatedType: "order",
                relatedId: order._id,
                actorUid: user.uid,
                targetRole: "traveler",
            });

            return res.status(200).json({
                success: true,
                ratingId: ratingResult.insertedId.toString(),
                ...summary,
            });
        } catch (err) {
            console.error("submitTravelerRating error:", err);
            return res.status(500).json({ error: "Server error" });
        }
    })
);

const skipTravelerRating = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        try {
            const { orderId } = req.body || {};

            if (!orderId || !ObjectId.isValid(orderId)) {
                return res.status(400).json({ error: "Invalid order id" });
            }

            const orders = db.collection("orders");
            const ratings = db.collection("ratings");
            const order = await orders.findOne({ _id: new ObjectId(orderId) });

            if (!order) {
                return res.status(404).json({ error: "Order not found" });
            }

            if (order.buyerUid !== user.uid) {
                return res.status(403).json({ error: "Only the buyer can skip this rating" });
            }

            if (order.status !== "Received") {
                return res.status(400).json({ error: "Only received orders can be skipped" });
            }

            if (order.buyerRatingStatus === "noRating" || order.buyerRatingSkipped === true) {
                return res.status(200).json({ success: true, status: "noRating" });
            }

            if (order.buyerRatingStatus === "rated" || order.buyerRatingSubmitted === true) {
                return res.status(409).json({ error: "Rating already submitted" });
            }

            const now = new Date();
            const existingDecision = await ratings.findOne({
                orderId: order._id,
                buyerUid: user.uid,
            });

            let ratingId = existingDecision?._id || null;

            if (!existingDecision) {
                const result = await ratings.insertOne({
                    orderId: order._id,
                    buyerUid: order.buyerUid,
                    travelerUid: order.travelerUid,
                    status: "noRating",
                    createdAt: now,
                });

                ratingId = result.insertedId;
            }

            await orders.updateOne(
                { _id: order._id },
                {
                    $set: {
                        buyerRatingSubmitted: false,
                        buyerRatingSkipped: true,
                        buyerRatingStatus: "noRating",
                        travelerRatingId: ratingId,
                        ratingSkippedAt: now,
                        updatedAt: now,
                    },
                    $unset: {
                        travelerRatingValue: "",
                        travelerRatedAt: "",
                    },
                }
            );

            return res.status(200).json({ success: true, status: "noRating" });
        } catch (err) {
            console.error("skipTravelerRating error:", err);
            return res.status(500).json({ error: "Server error" });
        }
    })
);


// ================= SEND OFFER =================


const router = express.Router();

router.all("/submitTravelerRating", submitTravelerRating);
router.all("/skipTravelerRating", skipTravelerRating);

module.exports = router;

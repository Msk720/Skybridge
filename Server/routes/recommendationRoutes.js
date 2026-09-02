/**
 * Module: Routes
 * Purpose: Handles recommendation and search endpoints.
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

const getRecommendations = (async (req, res) => {
    setCorsHeaders(res);

    if (req.method === "OPTIONS") return res.status(204).send("");

    try {
        const { productId } = req.query;
        const { ObjectId } = require("mongodb");

        const client = await getMongoClient();
        const db = client.db("myDatabase");

        const product = await db.collection("Products").findOne({
            _id: new ObjectId(productId),
        });

        if (!product || !product.tags || product.tags.length < 2) {
            return res.json([]);
        }


        const categoryTag = product.tags[0];
        const brandTag = product.tags[1];

        const recommendations = await db.collection("Products").aggregate([
            {
                $match: {
                    _id: { $ne: new ObjectId(productId) },
                    tags: { $exists: true, $ne: [] }
                }
            },
            {
                $addFields: {
                    score: {
                        $add: [
                            {
                                $cond: [
                                    { $in: [categoryTag, "$tags"] },
                                    2,
                                    0
                                ]
                            },
                            {
                                $cond: [
                                    { $in: [brandTag, "$tags"] },
                                    3,
                                    0
                                ]
                            }
                        ]
                    }
                }
            },
            {
                $match: {
                    score: { $gt: 0 }
                }
            },
            {
                $sort: { score: -1 }
            },
            {
                $limit: 2
            }
        ]).toArray();

        const normalized = recommendations.map((doc) => ({
            ...doc,
            id: doc._id.toString(),
            _id: undefined,
        }));

        return res.status(200).json(normalized);

    } catch (err) {
        console.error("getRecommendations error:", err);
        return res.status(500).json({ error: "Server error" });
    }
});




const router = express.Router();

router.all("/getRecommendations", getRecommendations);

module.exports = router;

/**
 * Module: Routes
 * Purpose: Handles health/status routes.
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

const ping = (async (req, res) => {
    setCorsHeaders(res);
    if (req.method === "OPTIONS") return res.status(204).send("");
    try {
        const client = await getMongoClient();
        const status = await client.db("admin").command({ ping: 1 });
        res.json({ ok: true, status });
    } catch (err) {
        console.error("Ping error:", err);
        res.status(500).json({ error: "DB unreachable" });
    }
});
// POST /saveProfile (protected)


const router = express.Router();

router.all("/ping", ping);

module.exports = router;

/**
 * Module: Routes
 * Purpose: Handles notification endpoints.
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

const getNotifications = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (req.method !== "GET") {
            return res.status(405).send("Only GET allowed");
        }

        try {
            const limit = Math.min(parseInt(req.query.limit) || 50, 100);
            const unreadOnly = req.query.unreadOnly === "true";
            const targetRole = ["buyer", "traveler"].includes(req.query.role)
                ? req.query.role
                : null;

            const filter = { userId: user.uid };
            if (unreadOnly) {
                filter.isRead = false;
            }
            if (targetRole) {
                filter.targetRole = targetRole;
            }

            const [notifications, unreadCount] = await Promise.all([
                db.collection("notifications")
                    .find(filter)
                    .sort({ createdAt: -1 })
                    .limit(limit)
                    .toArray(),
                db.collection("notifications").countDocuments({
                    userId: user.uid,
                    isRead: false,
                }),
            ]);

            return res.status(200).json({
                success: true,
                unreadCount,
                data: notifications.map(normalizeNotification),
            });
        } catch (err) {
            console.error("getNotifications error:", err);
            return res.status(500).json({ error: "Server error" });
        }
    })
);

const markNotificationRead = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        try {
            const { id, all } = req.body || {};
            const now = new Date();

            if (all === true) {
                await db.collection("notifications").updateMany(
                    { userId: user.uid, isRead: false },
                    {
                        $set: {
                            isRead: true,
                            readAt: now,
                            updatedAt: now,
                        },
                    }
                );

                return res.status(200).json({ success: true });
            }

            if (!id || !ObjectId.isValid(id)) {
                return res.status(400).json({ error: "Invalid notification id" });
            }

            await db.collection("notifications").updateOne(
                { _id: new ObjectId(id), userId: user.uid },
                {
                    $set: {
                        isRead: true,
                        readAt: now,
                        updatedAt: now,
                    },
                }
            );

            return res.status(200).json({ success: true });
        } catch (err) {
            console.error("markNotificationRead error:", err);
            return res.status(500).json({ error: "Server error" });
        }
    })
);


// ================= RATINGS =================


const router = express.Router();

router.all("/getNotifications", getNotifications);
router.all("/markNotificationRead", markNotificationRead);

module.exports = router;

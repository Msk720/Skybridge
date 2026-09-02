/**
 * Module: Routes
 * Purpose: Handles profile endpoints.
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

const saveProfile = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        const body = req.body || {};

        const profileData = {
            userId: user.uid,
            name: body.name || "",
            email: body.email || user.email || "",
            contact: body.contact || "",
            address: body.address || "",
            profilePicUrl: body.profilePicUrl || "",

            isComplete:
                !!body.name &&
                !!body.email &&
                !!body.contact &&
                !!body.address &&
                !!body.profilePicUrl,

            updatedAt: new Date(),
        };

        try {
            await db.collection("profiles").updateOne(
                { userId: user.uid },
                {
                    $set: profileData,
                    $setOnInsert: {
                        createdAt: new Date(),
                    },
                },
                { upsert: true }
            );

            return res.status(200).json({
                success: true,
                isComplete: profileData.isComplete,
            });
        } catch (err) {
            console.error("saveProfile error:", err);
            return res.status(500).json({ error: "Server error" });
        }
    })
);


const getProfile = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (req.method !== "GET") {
            return res.status(405).send("Only GET allowed");
        }

        try {
            const profile = await db
                .collection("profiles")
                .findOne({ userId: user.uid });

            let stripeConnect = await db
                .collection("stripeconnect")
                .findOne({
                    userId: user.uid,
                    provider: "stripe",
                });

            if (!stripeConnect && profile?.stripeAccountId) {
                const migrated = await ensureStripeConnectForUser(db, user, profile);
                stripeConnect = migrated.stripeConnect;
            }

            if (!profile) {
                return res.status(200).json({
                    userId: user.uid,
                    email: user.email || "",
                    name: "",
                    contact: "",
                    address: "",
                    profilePicUrl: "",
                    isComplete: false,
                    ratingAverage: 0,
                    ratingCount: 0,
                    stripeConnectId: stripeConnect?._id?.toString() || "",
                    stripeAccountId: stripeConnect?.stripeAccountId || "",
                    stripeDetailsSubmitted: !!stripeConnect?.stripeDetailsSubmitted,
                    stripePayoutsEnabled: !!stripeConnect?.stripePayoutsEnabled,
                    stripeChargesEnabled: !!stripeConnect?.stripeChargesEnabled,
                    stripeCurrentlyDue: stripeConnect?.stripeCurrentlyDue || [],
                    stripePastDue: stripeConnect?.stripePastDue || [],
                    stripeDisabledReason: stripeConnect?.stripeDisabledReason || null,
                });
            }

            const out = {
                ...profile,
                email: profile.email || user.email || "",
                stripeConnectId: stripeConnect?._id?.toString() || profile.stripeConnectId?.toString?.() || "",
                stripeAccountId: stripeConnect?.stripeAccountId || "",
                stripeDetailsSubmitted: !!stripeConnect?.stripeDetailsSubmitted,
                stripePayoutsEnabled: !!stripeConnect?.stripePayoutsEnabled,
                stripeChargesEnabled: !!stripeConnect?.stripeChargesEnabled,
                stripeCurrentlyDue: stripeConnect?.stripeCurrentlyDue || [],
                stripePastDue: stripeConnect?.stripePastDue || [],
                stripeDisabledReason: stripeConnect?.stripeDisabledReason || null,
                ratingAverage: Number(profile.ratingAverage || 0),
                ratingCount: Number(profile.ratingCount || 0),
            };

            delete out._id;
            delete out.deals;
            delete out.orders;
            delete out.shipments;
            delete out.trips;
            delete out.completedOrders;
            delete out.stripeConnectType;
            delete out.stripeAccountStatusUpdatedAt;
            delete out.lastStripePayoutId;
            delete out.lastStripePayoutStatus;
            delete out.lastStripePayoutAmount;
            delete out.lastStripePayoutCurrency;
            delete out.lastStripePayoutAt;

            return res.status(200).json(out);
        } catch (err) {
            console.error("getProfile error:", err);
            return res.status(500).json({ error: "Server error" });
        }
    })
);


const getProfileStats = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        if (req.method !== "GET") {
            return res.status(405).send("Only GET allowed");
        }

        try {
            const stats = await buildProfileStats(db, user.uid);

            return res.status(200).json({
                success: true,
                data: stats,
            });
        } catch (err) {
            console.error("getProfileStats error:", err);
            return res.status(500).json({ error: "Server error" });
        }
    })
);


// ================= NOTIFICATIONS =================


const router = express.Router();

router.all("/saveProfile", saveProfile);
router.all("/getProfile", getProfile);
router.all("/getProfileStats", getProfileStats);

module.exports = router;

/**
 * Module: Routes
 * Purpose: Handles automatic expiration and cleanup of entities.
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

async function runAutoExpireEntities() {
    console.log("⏳ autoExpireEntities started");

    const client = await getMongoClient();
    const db = client.db("myDatabase");

    const nowUTC = new Date();
    const nowPK = new Date(nowUTC.getTime() + 5 * 60 * 60 * 1000);

    const startOfTodayPKUTC = (() => {
        const d = new Date(nowPK);
        d.setHours(0, 0, 0, 0);
        return new Date(d.getTime() - 5 * 60 * 60 * 1000);
    })();

    const expireTripsBeforePK = new Date(nowPK.getTime() + 4 * 60 * 60 * 1000);
    const now = new Date();
    const cleanedRatings = await cleanupRatingDocuments(db);

    const activeItems = await db.collection("items").find({
        status: "Active",
        date: { $exists: true },
    }).toArray();

    const expiredItemIds = [];

    for (const item of activeItems) {
        const itemDate = new Date(item.date);

        if (isNaN(itemDate.getTime())) continue;

        if (itemDate < startOfTodayPKUTC) {
            await db.collection("items").updateOne(
                { _id: item._id },
                {
                    $set: {
                        status: "Inactive",
                        expiredAt: now,
                        inactiveReason: "Shipment date passed",
                        updatedAt: now,
                    },
                    $push: {
                        statusHistory: statusHistoryEntry(
                            "Inactive",
                            "system",
                            "Shipment date passed"
                        ),
                    },
                }
            );

            expiredItemIds.push(item._id);
        }
    }

    console.log("📦 Items expired:", expiredItemIds.length);

    const activeTrips = await db.collection("trips").find({
        $or: [{ stat: "Active" }, { status: "Active" }],
    }).toArray();

    const expiredTripIds = [];

    for (const trip of activeTrips) {
        let parsedPK = new Date(`${trip.departureDate} ${trip.departureTime || ""}`);

        if (isNaN(parsedPK.getTime())) {
            parsedPK = new Date(trip.departureDate);
        }

        if (isNaN(parsedPK.getTime())) continue;

        if (parsedPK <= expireTripsBeforePK) {
            await db.collection("trips").updateOne(
                { _id: trip._id },
                {
                    $set: {
                        status: "Inactive",
                        stat: "Inactive",
                        expiredAt: now,
                        inactiveReason: "Trip departure time passed",
                        updatedAt: now,
                    },
                    $push: {
                        statusHistory: statusHistoryEntry(
                            "Inactive",
                            "system",
                            "Trip departure time passed"
                        ),
                    },
                }
            );

            expiredTripIds.push(trip._id);
        }
    }

    console.log("✈️ Trips expired:", expiredTripIds.length);

    const directExpiredOfferCount = await expireRelatedOffers(db, {
        itemIds: expiredItemIds,
        tripIds: expiredTripIds,
        reason: "Related shipment or trip expired",
    });

    const unavailableLinkOfferCount = await expireOffersWithUnavailableLinks(db);
    const inactiveOrderCount = await inactivateOverdueOrders(db, startOfTodayPKUTC);

    console.log("💰 Offers expired:", directExpiredOfferCount + unavailableLinkOfferCount);
    console.log("📦 Orders inactivated:", inactiveOrderCount);
    console.log("✅ autoExpireEntities completed");

    return {
        success: true,
        expiredItems: expiredItemIds.length,
        expiredTrips: expiredTripIds.length,
        expiredOffers: directExpiredOfferCount + unavailableLinkOfferCount,
        inactiveOrders: inactiveOrderCount,
        cleanedRatings,
    };
}

const autoExpireEntities = (async (req, res) => {
    try {
        const result = await runAutoExpireEntities();
        return res.json(result);
    } catch (err) {
        console.error("❌ autoExpireEntities failed:", err);
        return res.status(500).json({ error: "Auto expire failed" });
    }
});

const scheduledAutoExpireEntities = async () => {
    return runAutoExpireEntities();
};





const router = express.Router();

router.all("/autoExpireEntities", autoExpireEntities);
router.all("/scheduledAutoExpireEntities", async (req, res) => {
  try {
    const result = await scheduledAutoExpireEntities();
    return res.json(result);
  } catch (error) {
    console.error("scheduledAutoExpireEntities error:", error);
    return res.status(500).json({ error: "scheduledAutoExpireEntities failed" });
  }
});

module.exports = router;

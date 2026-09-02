/**
 * Module: Unified Utilities
 * Purpose: Provides helper functions used by backend routes, middleware, or data mapping logic.
 */
const crypto = require("crypto");
const jwt = require("jsonwebtoken");
const { ObjectId } = require("mongodb");
const Account = require("../models/Account");
const { verifyFirebaseToken } = require("../utils/firebaseToken");
const { getMongoClient } = require("../config/db");
const stripe = require("../config/stripe");

function setCorsHeaders(res) {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader(
        "Access-Control-Allow-Methods",
        "GET,POST,OPTIONS,PUT,DELETE"
    );
    res.setHeader(
        "Access-Control-Allow-Headers",
        "Content-Type, Authorization"
    );
}

// ================= VERIFY FIREBASE TOKEN ============================

async function verifyToken(req) {
    const header = req.get("Authorization") || "";

    if (!header.startsWith("Bearer ")) {
        throw { status: 401, message: "Missing Authorization header" };
    }

    const token = header.split("Bearer ")[1];

    try {
        return await verifyFirebaseToken(token);
    } catch (firebaseError) {
        if (!process.env.JWT_SECRET) {
            console.error("Token verification failed", firebaseError);
            throw { status: 401, message: "Invalid token" };
        }

        try {
            const decoded = jwt.verify(token, process.env.JWT_SECRET);
            const account = await Account.findById(decoded.id).select("-password");

            if (!account) {
                throw new Error("Account not found");
            }

            const id = account._id.toString();

            return {
                uid: id,
                userId: id,
                email: account.email || "",
                name: account.name || "",
                role: String(account.role || "user").toLowerCase(),
            };
        } catch (jwtError) {
            console.error("Token verification failed", jwtError);
            throw { status: 401, message: "Invalid token" };
        }
    }
}


function hashDeliveryQrToken(token) {
    return crypto.createHash("sha256").update(token).digest("hex");
}

function toStripeCents(amount) {
    const value = Number(amount);
    if (!Number.isFinite(value) || value <= 0) return 0;
    return Math.round(value * 100);
}

function getStripeConnectReturnUrl() {
    return process.env.STRIPE_CONNECT_RETURN_URL || "https://example.com";
}

function getStripeConnectCountry() {
    return process.env.STRIPE_CONNECT_COUNTRY || "US";
}

function getStripeCurrency() {
    return process.env.STRIPE_CURRENCY || "usd";
}

function getOrderIdFromMetadata(metadata) {
    return metadata && metadata.orderId && ObjectId.isValid(metadata.orderId)
        ? new ObjectId(metadata.orderId)
        : null;
}

async function buildProfileStats(db, userId) {
    const [shipments, trips, completedOrders] = await Promise.all([
        db.collection("items").countDocuments({ userId }),
        db.collection("trips").countDocuments({ userId }),
        db.collection("orders").countDocuments({
            status: "Received",
            $or: [
                { buyerUid: userId },
                { travelerUid: userId }
            ]
        }),
    ]);

    return {
        shipments,
        trips,
        orders: completedOrders,
        completedOrders,
        deals: completedOrders,
    };
}

function moneyFromStripeAmount(amount) {
    return typeof amount === "number" ? amount / 100 : null;
}

function safeObjectIdString(value) {
    if (!value) return "";
    return value.toString ? value.toString() : String(value);
}

function statusHistoryEntry(status, by, note) {
    return {
        status,
        by,
        note,
        at: new Date(),
    };
}

function notificationRelatedId(value) {
    if (!value) return null;
    return value.toString ? value.toString() : String(value);
}

async function createNotification(db, {
    userId,
    type,
    title,
    message,
    relatedType = null,
    relatedId = null,
    actorUid = null,
    targetRole = null,
}) {
    if (!userId || !type || !title || !message) return null;

    const now = new Date();

    return db.collection("notifications").insertOne({
        userId,
        type,
        title,
        message,
        relatedType,
        relatedId: notificationRelatedId(relatedId),
        actorUid,
        targetRole,
        isRead: false,
        createdAt: now,
        readAt: null,
    });
}

async function createNotifications(db, notifications) {
    const cleanNotifications = notifications.filter(Boolean);
    if (!cleanNotifications.length) return;
    await Promise.all(cleanNotifications.map((notification) => createNotification(db, notification)));
}

function normalizeNotification(doc) {
    return {
        ...doc,
        id: doc._id.toString(),
        _id: undefined,
        relatedId: notificationRelatedId(doc.relatedId),
    };
}

function hasBuyerRatingDecision(order) {
    return order.buyerRatingSubmitted === true ||
        order.buyerRatingSkipped === true ||
        order.buyerRatingStatus === "rated" ||
        order.buyerRatingStatus === "noRating";
}

function isInactiveEntity(doc) {
    if (!doc) return true;

    const status = doc.status || doc.stat || "Active";
    return status !== "Active";
}

async function expireRelatedOffers(db, { itemIds = [], tripIds = [], reason, actorUid = "system" }) {
    const clauses = [];

    if (itemIds.length) {
        clauses.push({ itemId: { $in: itemIds } });
    }

    if (tripIds.length) {
        clauses.push({ tripId: { $in: tripIds } });
    }

    if (!clauses.length) {
        return 0;
    }

    const now = new Date();
    const result = await db.collection("offers").updateMany(
        {
            $or: clauses,
            status: { $nin: ["Expired", "Rejected", "Cancelled", "Closed"] },
        },
        {
            $set: {
                status: "Expired",
                isActive: false,
                expiredAt: now,
                expiredReason: reason,
                updatedAt: now,
            },
            $push: {
                statusHistory: statusHistoryEntry("Expired", actorUid, reason),
            },
        }
    );

    return result.modifiedCount || 0;
}

async function expireOffersWithUnavailableLinks(db) {
    const offers = await db.collection("offers").find({
        status: { $nin: ["Expired", "Rejected", "Cancelled", "Closed"] },
    }).toArray();

    let expiredOfferCount = 0;

    for (const offer of offers) {
        const [item, trip] = await Promise.all([
            offer.itemId ? db.collection("items").findOne({ _id: offer.itemId }) : null,
            offer.tripId ? db.collection("trips").findOne({ _id: offer.tripId }) : null,
        ]);

        if (isInactiveEntity(item) || isInactiveEntity(trip)) {
            const now = new Date();
            const result = await db.collection("offers").updateOne(
                { _id: offer._id },
                {
                    $set: {
                        status: "Expired",
                        isActive: false,
                        expiredAt: now,
                        expiredReason: "Related shipment or trip is unavailable",
                        updatedAt: now,
                    },
                    $push: {
                        statusHistory: statusHistoryEntry(
                            "Expired",
                            "system",
                            "Related shipment or trip is unavailable"
                        ),
                    },
                }
            );

            expiredOfferCount += result.modifiedCount || 0;
        }
    }

    return expiredOfferCount;
}

function normalizeDateOnly(value) {
    if (!value) return null;

    const parsed = new Date(value);
    return isNaN(parsed.getTime()) ? null : parsed;
}

async function inactivateOverdueOrders(db, startOfTodayPKUTC) {
    const openOrders = await db.collection("orders").find({
        status: { $in: ["Placed", "InTransit"] },
    }).toArray();

    let inactiveOrderCount = 0;

    for (const order of openOrders) {
        let deliveryDate = normalizeDateOnly(
            order.deliveryDate ||
            order.expectedDeliveryDate ||
            order.departureDate ||
            order.date
        );

        if (!deliveryDate && order.tripId) {
            const trip = await db.collection("trips").findOne({ _id: order.tripId });
            deliveryDate = normalizeDateOnly(trip?.departureDate);
        }

        if (!deliveryDate || deliveryDate >= startOfTodayPKUTC) {
            continue;
        }

        const now = new Date();
        const result = await db.collection("orders").updateOne(
            { _id: order._id, status: { $in: ["Placed", "InTransit"] } },
            {
                $set: {
                    status: "Inactive",
                    inactiveReason: "Delivery date passed before order was received",
                    inactivatedAt: now,
                    updatedAt: now,
                },
                $push: {
                    statusHistory: statusHistoryEntry(
                        "Inactive",
                        "system",
                        "Delivery date passed before order was received"
                    ),
                },
            }
        );

        inactiveOrderCount += result.modifiedCount || 0;
    }

    return inactiveOrderCount;
}

async function cleanupRatingDocuments(db) {
    await db.collection("ratings").updateMany(
        { isSkipped: true },
        {
            $set: { status: "noRating" },
            $unset: {
                comment: "",
                tripId: "",
                itemId: "",
                isSkipped: "",
                updatedAt: "",
            },
        }
    );

    const result = await db.collection("ratings").updateMany(
        {
            $or: [
                { comment: { $exists: true } },
                { tripId: { $exists: true } },
                { itemId: { $exists: true } },
                { isSkipped: { $exists: true } },
                { updatedAt: { $exists: true } },
            ],
        },
        {
            $unset: {
                comment: "",
                tripId: "",
                itemId: "",
                isSkipped: "",
                updatedAt: "",
            },
        }
    );

    return result.modifiedCount || 0;
}

async function refreshTravelerRatingSummary(db, travelerUid) {
    const summary = await db.collection("ratings").aggregate([
        {
            $match: {
                travelerUid,
                rating: { $gte: 1, $lte: 5 },
                status: { $ne: "noRating" },
            },
        },
        {
            $group: {
                _id: null,
                ratingAverage: { $avg: "$rating" },
                ratingCount: { $sum: 1 },
            },
        },
    ]).toArray();

    const ratingAverage = summary.length
        ? Math.round(Number(summary[0].ratingAverage || 0) * 10) / 10
        : 0;
    const ratingCount = summary.length ? Number(summary[0].ratingCount || 0) : 0;

    await db.collection("profiles").updateOne(
        { userId: travelerUid },
        {
            $set: {
                ratingAverage,
                ratingCount,
                ratingUpdatedAt: new Date(),
                updatedAt: new Date(),
            },
            $setOnInsert: {
                userId: travelerUid,
                isComplete: false,
                createdAt: new Date(),
            },
        },
        { upsert: true }
    );

    return { ratingAverage, ratingCount };
}

function normalizeObjectId(value) {
    if (!value) return null;
    if (value instanceof ObjectId) return value;
    const stringValue = value.toString ? value.toString() : String(value);
    return ObjectId.isValid(stringValue) ? new ObjectId(stringValue) : null;
}

function getPaymentIdFromMetadata(metadata) {
    return metadata && metadata.paymentId && ObjectId.isValid(metadata.paymentId)
        ? new ObjectId(metadata.paymentId)
        : null;
}

async function ensureStripeConnectForUser(db, user, profile = null) {
    const profiles = db.collection("profiles");
    const stripeConnectCollection = db.collection("stripeconnect");

    let userProfile = profile;

    if (!userProfile) {
        userProfile = await profiles.findOne({ userId: user.uid });
    }

    if (!userProfile) {
        const fallbackProfile = {
            userId: user.uid,
            email: user.email || "",
            name: user.name || "",
            isComplete: false,
            createdAt: new Date(),
            updatedAt: new Date(),
        };

        await profiles.insertOne(fallbackProfile);
        userProfile = fallbackProfile;
    }

    let stripeConnect = await stripeConnectCollection.findOne({
        userId: user.uid,
        provider: "stripe",
    });

    if (!stripeConnect && userProfile.stripeAccountId) {
        const now = new Date();
        const accountDoc = {
            userId: user.uid,
            provider: "stripe",
            connectType: userProfile.stripeConnectType || "express",
            stripeAccountId: userProfile.stripeAccountId,
            stripeDetailsSubmitted: !!userProfile.stripeDetailsSubmitted,
            stripePayoutsEnabled: !!userProfile.stripePayoutsEnabled,
            stripeChargesEnabled: !!userProfile.stripeChargesEnabled,
            stripeCurrentlyDue: userProfile.stripeCurrentlyDue || [],
            stripePastDue: userProfile.stripePastDue || [],
            stripeDisabledReason: userProfile.stripeDisabledReason || null,
            stripeConnectCountry: userProfile.stripeConnectCountry || getStripeConnectCountry(),
            createdAt: now,
            updatedAt: now,
        };

        const result = await stripeConnectCollection.insertOne(accountDoc);
        stripeConnect = {
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
            }
        );
    }

    return {
        profile: userProfile,
        stripeConnect,
    };
}

function withAuthAndDb(handler) {
    return async (req, res) => {

        // Allow dev browser preflight and requests
        res.setHeader("Access-Control-Allow-Origin", "*");
        res.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS,PUT,DELETE");
        res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");

        if (req.method === "OPTIONS") return res.status(204).send("");

        try {
            const user = await verifyToken(req);
            const client = await getMongoClient();
            const db = client.db("myDatabase");

            const profile = await db.collection("profiles").findOne(
                { userId: user.uid },
                { projection: { status: 1 } }
            );

            if (profile?.status === "blocked") {
                return res.status(403).json({
                    error: "This account is restricted. Please contact support.",
                });
            }

            await handler({ req, res, db, user });

        } catch (err) {
            console.error("Function error:", err);
            res.status(err.status || 500).json({ error: err.message || "Server error" });
        }
    };
}



module.exports = {
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
    withAuthAndDb
};

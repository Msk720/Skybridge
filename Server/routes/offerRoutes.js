/**
 * Module: Routes
 * Purpose: Handles offer creation and offer state changes.
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

const sendOffer = (
    withAuthAndDb(async ({ req, res, db, user }) => {
        try {
            if (req.method !== "POST") {
                return res.status(405).send("Only POST allowed");
            }

            const {
                itemId,
                tripId,
                buyerUid,
                originalReward,
                offeredReward,
                departureDate: requestedDepartureDate,
            } = req.body;

            if (!tripId || !ObjectId.isValid(tripId)) {
                return res.status(400).json({ error: "Invalid or missing tripId" });
            }

            if (!itemId || !ObjectId.isValid(itemId)) {
                return res.status(400).json({ error: "Invalid or missing itemId" });
            }

            // 🔹 Fetch trip
            const trip = await db.collection("trips").findOne({
                _id: new ObjectId(tripId),
            });

            if (!trip) {
                return res.status(404).json({ error: "Trip not found" });
            }

            if (trip.userId !== user.uid) {
                return res.status(403).json({
                    error: "Trip does not belong to this traveler",
                });
            }


            const item = await db.collection("items").findOne({
                _id: new ObjectId(itemId),
            });

            if (!item) {
                return res.status(404).json({ error: "Item not found" });
            }

            const itemPrice = Number(item.itemPrice ?? 0);
            const totalAmount = itemPrice + offeredReward;
            const tripDepartureDate = trip.departureDate;

            const offer = {
                itemId: new ObjectId(itemId),
                tripId: new ObjectId(tripId),

                buyerUid,
                travelerUid: user.uid,
                totalAmount: totalAmount,
                offeredReward: Number(offeredReward),
                originalReward: Number(originalReward),
                departureDate: trip.departureDate,


                status: "Pending",
                createdAt: new Date(),
            };

            const result = await db.collection("offers").insertOne(offer);

            await createNotification(db, {
                userId: buyerUid,
                type: "OFFER_RECEIVED",
                title: "New Offer Received",
                message: "A traveler sent an offer for your shipment.",
                relatedType: "offer",
                relatedId: result.insertedId,
                actorUid: user.uid,
                targetRole: "buyer",
            });

            return res.status(201).json({
                success: true,
                offerId: result.insertedId.toString(),

            });
        } catch (err) {
            console.error("SEND OFFER ERROR:", err);
            return res.status(500).json({
                error: "Internal error",
                detail: err.message,
            });
        }
    })
);



// ================================ findMyMatchingTrip  ======================================
const getMyMatchingTripId = (
    withAuthAndDb(async ({ req, res, db, user }) => {

        if (req.method !== "POST") {
            return res.status(405).send("Only POST allowed");
        }

        const {
            fromCountry,
            fromCity,
            toCountry,
            toCity,
            weight,
            date,
        } = req.body;

        console.log("📦 SHIPMENT INPUT:");
        console.log({
            fromCountry,
            fromCity,
            toCountry,
            toCity,
            weight,
            date,
        });

        const trips = await db.collection("trips").find({
            userId: user.uid,
            status: "Active",
            fromCountry,
            fromCity,
            toCountry,
            toCity,
        }).toArray();

        console.log("✈️ ALL USER TRIPS:", trips.length);
        console.log("✈️ TRIPS DATA:", trips);

        if (!trips.length) {
            console.log("❌ NO TRIPS MATCHING ROUTE");
            return res.json({ tripId: null });
        }

        const requestedDate = date ? new Date(date) : null;

        const match = trips.find(trip => {
            const tripDate = new Date(trip.departureDate);

            console.log("🔍 CHECKING TRIP:");
            console.log({
                tripId: trip._id.toString(),
                tripDate,
                requestedDate,
                tripWeight: trip.availableWeight,
                requiredWeight: weight,
            });

            if (requestedDate && tripDate > requestedDate) {
                console.log("❌ DATE FAILED");
                return false;
            }

            if (weight && Number(trip.availableWeight) < Number(weight)) {
                console.log("❌ WEIGHT FAILED");
                return false;
            }

            console.log("✅ MATCH FOUND");
            return true;
        });

        console.log("🎯 FINAL MATCH:", match);

        return res.json({
            tripId: match ? match._id.toString() : null,
        });
    })
);



// ================= updateEntityStatus  =================


const router = express.Router();

router.all("/sendOffer", sendOffer);
router.all("/getMyMatchingTripId", getMyMatchingTripId);

module.exports = router;

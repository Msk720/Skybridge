/**
 * Module: Utilities
 * Purpose: Reusable CRUD helpers for createData, listData, updateData, and deleteData.
 */
const mongoose = require("mongoose");
const { ObjectId } = require("mongodb");
const { connectDatabase } = require("../config/db");
const {
  getModelByCollection,
  getSearchModel,
  normalizeDoc,
} = require("./modelRegistry");
const {
  setCorsHeaders,
  withAuthAndDb,
  expireRelatedOffers,
} = require("./appUtils");

const publicCollections = new Set(["Products", "products"]);
const ownedCollections = new Set(["items", "trips"]);

function parseBody(req) {
  return typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body || {};
}

function isAdmin(user = {}) {
  return String(user.role || "").toLowerCase() === "admin";
}

function isProductCollection(collection) {
  return collection === "Products" || collection === "products";
}

function getSafeModel(collection) {
  const Model = getModelByCollection(collection);

  if (!Model) {
    const allowed = ["Products", "products", "items", "trips", "offers", "orders", "profiles", "payments", "notifications", "ratings", "travelerAccounts", "stripeEvents"];
    const error = new Error(`Invalid collection. Allowed collections: ${allowed.join(", ")}`);
    error.statusCode = 400;
    throw error;
  }

  return Model;
}

function toMongooseId(id) {
  if (!mongoose.Types.ObjectId.isValid(id)) {
    const error = new Error("Invalid id");
    error.statusCode = 400;
    throw error;
  }

  return new mongoose.Types.ObjectId(id);
}

function removeProtectedFields(data = {}) {
  const cleanData = { ...data };

  delete cleanData._id;
  delete cleanData.id;

  return cleanData;
}

function cleanCollectionData(collection, data = {}) {
  const cleanData = removeProtectedFields(data);
  if (collection === "trips") {
    delete cleanData.preference;
  }
  return cleanData;
}

function objectIdString(value) {
  if (!value) return "";
  return value.toString ? value.toString() : String(value);
}

function duplicateOrderKey(order = {}) {
  const paymentKey = order.paymentIntentId || order.paymentReference;
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

function dedupeOrders(results = []) {
  const seen = new Set();
  return results.filter((order) => {
    const key = duplicateOrderKey(order);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function addOwnerIfNeeded(collection, data, user) {
  if (ownedCollections.has(collection) && !data.userId) {
    return { ...data, userId: user.uid };
  }

  return data;
}

function buildRecordFilter(collection, user, id = null) {
  const filter = {};

  if (id) {
    filter._id = toMongooseId(id);
  }

  if (!isAdmin(user) && !publicCollections.has(collection)) {
    filter.userId = user.uid;
  }

  return filter;
}

function buildListFilter(req, user) {
  const collection = req.query.collection;
  const filter = buildRecordFilter(collection, user);

  if (collection === "offers") {
    filter.buyerUid = user.uid;
    filter.status = "Pending";
    delete filter.userId;
  }

  if (req.query.category) {
    filter.category = req.query.category;
  }

  if (req.query.search) {
    filter.$or = [
      { name: { $regex: req.query.search, $options: "i" } },
      { category: { $regex: req.query.search, $options: "i" } },
      { storeName: { $regex: req.query.search, $options: "i" } },
      { tags: { $regex: req.query.search, $options: "i" } },
    ];
  }

  return filter;
}

const createData = withAuthAndDb(async ({ req, res, user }) => {
  if (req.method !== "POST") {
    return res.status(405).send("Only POST allowed");
  }

  try {
    await connectDatabase();

    const { collection, data } = parseBody(req);

    if (!collection || !data) {
      return res.status(400).json({ error: "Missing collection or data" });
    }

    const Model = getSafeModel(collection);
    const recordData = addOwnerIfNeeded(collection, cleanCollectionData(collection, data), user);

    const doc = await Model.create({
      ...recordData,
      createdAt: data.createdAt || new Date(),
      updatedAt: new Date(),
    });

    return res.status(201).json({
      success: true,
      insertedId: doc._id,
      data: normalizeDoc(doc),
    });
  } catch (err) {
    console.error("createData error:", err);
    return res.status(err.statusCode || 500).json({ error: err.statusCode ? err.message : "Server error" });
  }
});

const updateData = withAuthAndDb(async ({ req, res, user }) => {
  if (req.method !== "POST" && req.method !== "PUT") {
    return res.status(405).send("Only POST/PUT allowed");
  }

  try {
    await connectDatabase();

    const { collection, id, data } = parseBody(req);

    if (!collection || !id || !data) {
      return res.status(400).json({ error: "Missing collection, id or data" });
    }

    const Model = getSafeModel(collection);
    const cleanData = cleanCollectionData(collection, data);
    delete cleanData.userId;

    const update = { $set: { ...cleanData, updatedAt: new Date() } };
    if (collection === "trips") update.$unset = { preference: "" };

    const doc = await Model.findOneAndUpdate(
      buildRecordFilter(collection, user, id),
      update,
      { new: true, runValidators: true }
    );

    return res.status(200).json({
      success: !!doc,
      matchedCount: doc ? 1 : 0,
      modifiedCount: doc ? 1 : 0,
      data: doc ? normalizeDoc(doc) : null,
    });
  } catch (err) {
    console.error("updateData error:", err);
    return res.status(err.statusCode || 500).json({ error: err.statusCode ? err.message : "Server error" });
  }
});

const deleteData = withAuthAndDb(async ({ req, res, db, user }) => {
  if (req.method !== "POST" && req.method !== "DELETE") {
    return res.status(405).send("Only POST/DELETE allowed");
  }

  try {
    await connectDatabase();

    const { collection, id } = parseBody(req);

    if (!collection || !id) {
      return res.status(400).json({ error: "Missing collection or id" });
    }

    const Model = getSafeModel(collection);
    const doc = await Model.findOneAndDelete(buildRecordFilter(collection, user, id));

    let expiredOffers = 0;

    if (doc && collection === "items") {
      expiredOffers = await expireRelatedOffers(db, {
        itemIds: [new ObjectId(id)],
        reason: "Related shipment was deleted",
        actorUid: user.uid,
      });
    }

    if (doc && collection === "trips") {
      expiredOffers = await expireRelatedOffers(db, {
        tripIds: [new ObjectId(id)],
        reason: "Related trip was deleted",
        actorUid: user.uid,
      });
    }

    return res.status(200).json({
      success: !!doc,
      deletedCount: doc ? 1 : 0,
      expiredOffers,
    });
  } catch (err) {
    console.error("deleteData error:", err);
    return res.status(err.statusCode || 500).json({ error: err.statusCode ? err.message : "Server error" });
  }
});

const listData = withAuthAndDb(async ({ req, res, user }) => {
  if (req.method !== "GET") {
    return res.status(405).send("Only GET allowed");
  }

  try {
    await connectDatabase();

    const collection = req.query.collection;
    const limit = parseInt(req.query.limit, 10) || 100;

    if (!collection) {
      return res.status(400).json({ error: "Missing collection name" });
    }

    const Model = getSafeModel(collection);
    const filter = buildListFilter(req, user);
    const docs = await Model.find(filter).sort({ createdAt: -1, _id: -1 }).limit(limit).lean();

    return res.json({
      success: true,
      count: docs.length,
      data: docs.map(normalizeDoc),
    });
  } catch (err) {
    console.error("listData error:", err);
    return res.status(err.statusCode || 500).json({ error: err.statusCode ? err.message : "Server error" });
  }
});

const searchData = withAuthAndDb(async ({ req, res, user }) => {
  setCorsHeaders(res);
  if (req.method === "OPTIONS") return res.status(204).send("");
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Only POST allowed" });
  }

  try {
    await connectDatabase();

    const {
      type,
      fromCountry,
      fromCity,
      toCountry,
      toCity,
      weight,
      date,
    } = parseBody(req) || {};

    const Model = getSearchModel(type);
    const query = {
      status: "Active",
      userId: { $ne: user.uid },
    };

    if (fromCountry) query.fromCountry = fromCountry;
    if (fromCity) query.fromCity = fromCity;
    if (toCountry) query.toCountry = toCountry;
    if (toCity) query.toCity = toCity;

    if (weight) {
      if (type === "shipments") {
        query.weightTotal = { $lte: Number(weight) };
      } else {
        query.availableWeight = { $gte: Number(weight) };
      }
    }

    if (date) {
      if (type === "shipments") {
        query.date = { $gte: date };
      } else {
        query.departureDate = { $lte: date };
      }
    }

    const results = await Model.aggregate([
      { $match: query },
      {
        $lookup: {
          from: "profiles",
          localField: "userId",
          foreignField: "userId",
          as: "user",
        },
      },
      {
        $unwind: {
          path: "$user",
          preserveNullAndEmptyArrays: true,
        },
      },
      {
        $addFields: {
          ownerName: { $ifNull: ["$user.name", "—"] },
          ownerImage: { $ifNull: ["$user.profilePicUrl", ""] },
        },
      },
      { $project: { user: 0 } },
      { $sort: { createdAt: -1 } },
      { $limit: 100 },
    ]);

    return res.status(200).json({
      success: true,
      data: results.map(normalizeDoc),
    });
  } catch (err) {
    console.error("searchData error:", err);
    return res.status(500).json({ error: "Search failed" });
  }
});

const listSearchData = withAuthAndDb(async ({ req, res, user }) => {
  setCorsHeaders(res);
  if (req.method === "OPTIONS") return res.status(204).send("");
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Only POST allowed" });
  }

  try {
    await connectDatabase();

    const { type } = parseBody(req) || {};
    const Model = getSearchModel(type);
    const query = {
      status: "Active",
      userId: { $ne: user.uid },
    };

    const results = await Model.aggregate([
      { $match: query },
      {
        $lookup: {
          from: "profiles",
          localField: "userId",
          foreignField: "userId",
          as: "user",
        },
      },
      {
        $unwind: {
          path: "$user",
          preserveNullAndEmptyArrays: true,
        },
      },
      {
        $addFields: {
          ownerName: { $ifNull: ["$user.name", "—"] },
          ownerImage: { $ifNull: ["$user.profilePicUrl", ""] },
        },
      },
      { $project: { user: 0 } },
      { $sort: { createdAt: -1 } },
      { $limit: 100 },
    ]);

    return res.status(200).json({
      success: true,
      data: results.map(normalizeDoc),
    });
  } catch (err) {
    console.error("listSearchData error:", err);
    return res.status(500).json({ error: "List fetch failed" });
  }
});

const listDataWithDetails = withAuthAndDb(async ({ req, res, user }) => {
  if (req.method !== "GET") {
    return res.status(405).send("Only GET allowed");
  }

  try {
    await connectDatabase();

    const collection = req.query.collection;
    const role = req.query.role;
    const limit = parseInt(req.query.limit, 10) || 100;

    if (!collection) {
      return res.status(400).json({ error: "Missing collection name" });
    }

    const Model = getSafeModel(collection);
    let match = {};
    let profileField = "travelerUid";

    if (collection === "offers") {
      if (role === "traveler") {
        profileField = "buyerUid";
        match = { travelerUid: user.uid };
      } else {
        profileField = "travelerUid";
        match = {
          buyerUid: user.uid,
          status: "Pending",
        };
      }

      if (req.query.status && req.query.status !== "all") {
        match.status = req.query.status;
      }
    } else if (collection === "orders") {
      profileField = role === "buyer" ? "travelerUid" : "buyerUid";

      if (!role || !["buyer", "traveler"].includes(role)) {
        return res.status(400).json({ error: "role is required" });
      }

      match = role === "buyer"
        ? { buyerUid: user.uid }
        : { travelerUid: user.uid };

      if (req.query.status) {
        match.status = req.query.status;
      }
    }

    const results = await Model.aggregate([
      { $match: match },
      {
        $lookup: {
          from: "items",
          localField: "itemId",
          foreignField: "_id",
          as: "item",
        },
      },
      { $unwind: { path: "$item", preserveNullAndEmptyArrays: true } },
      {
        $lookup: {
          from: "trips",
          localField: "tripId",
          foreignField: "_id",
          as: "trip",
        },
      },
      { $unwind: { path: "$trip", preserveNullAndEmptyArrays: true } },
      {
        $lookup: {
          from: "profiles",
          localField: profileField,
          foreignField: "userId",
          as: "user",
        },
      },
      { $unwind: { path: "$user", preserveNullAndEmptyArrays: true } },
      ...(collection === "orders"
        ? [
          {
            $lookup: {
              from: "payments",
              localField: "paymentId",
              foreignField: "_id",
              as: "payment",
            },
          },
          { $unwind: { path: "$payment", preserveNullAndEmptyArrays: true } },
        ]
        : []),
      {
        $addFields: {
          itemName: "$item.name",
          itemImage: "$item.image",
          fromCity: "$trip.fromCity",
          toCity: "$trip.toCity",
          fromCountry: "$trip.fromCountry",
          toCountry: "$trip.toCountry",
          departureDate: "$trip.departureDate",
          ...(collection === "orders" && {
            viewerRole: role,
            paymentIntentId: { $ifNull: ["$payment.paymentIntentId", "$paymentIntentId"] },
            paymentReference: { $ifNull: ["$payment.paymentReference", "$paymentReference"] },
            paymentStatus: { $ifNull: ["$payment.paymentStatus", { $ifNull: ["$paymentStatus", "PENDING"] }] },
            travelerPaymentStatus: { $ifNull: ["$payment.travelerPaymentStatus", { $ifNull: ["$travelerPaymentStatus", "PENDING"] }] },
          }),
          ownerName: { $ifNull: ["$user.name", "—"] },
          ownerImage: { $ifNull: ["$user.profilePicUrl", ""] },
        },
      },
      { $project: { item: 0, trip: 0, user: 0, payment: 0 } },
      { $sort: { createdAt: -1 } },
      { $limit: limit },
    ]);

    const finalResults = collection === "orders" ? dedupeOrders(results) : results;

    return res.json({
      success: true,
      data: finalResults.map(normalizeDoc),
    });
  } catch (err) {
    console.error("listDataWithDetails error:", err);
    return res.status(err.statusCode || 500).json({ error: err.statusCode ? err.message : "Server error" });
  }
});

module.exports = {
  createData,
  updateData,
  deleteData,
  listData,
  searchData,
  listSearchData,
  listDataWithDetails,
};

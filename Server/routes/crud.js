/**
 * Module: Routes
 * Purpose: Handles simple reusable CRUD endpoints for Products, items, trips, and profiles only.
 */
const express = require("express");
const mongoose = require("mongoose");
const createFlexibleModel = require("../models/flexibleModelFactory");
const { withAuthAndDb, expireRelatedOffers } = require("../utils/appUtils");
const { ObjectId } = require("mongodb");

const router = express.Router();

const collectionMap = {
  Products: "Products",
  products: "Products",
  items: "items",
  trips: "trips",
  profiles: "profiles",
};

const modelNameMap = {
  Products: "CrudProduct",
  products: "CrudProduct",
  items: "CrudItem",
  trips: "CrudTrip",
  profiles: "CrudProfile",
};

const publicCollections = new Set(["Products", "products"]);
const ownedCollections = new Set(["items", "trips", "profiles"]);

function parseBody(req) {
  return typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body || {};
}

function isAdmin(user = {}) {
  return String(user.role || "").toLowerCase() === "admin";
}

function getUserId(user = {}) {
  return user.uid || user.userId || user._id || "";
}

function getModel(collection) {
  const collectionName = collectionMap[collection];

  if (!collectionName) {
    const error = new Error("Invalid collection. Allowed collections: Products, items, trips, profiles");
    error.statusCode = 400;
    throw error;
  }

  return createFlexibleModel(modelNameMap[collection], collectionName);
}

function toObjectId(id) {
  if (!mongoose.Types.ObjectId.isValid(id)) {
    const error = new Error("Invalid id");
    error.statusCode = 400;
    throw error;
  }

  return new mongoose.Types.ObjectId(id);
}

function normalizeDoc(doc) {
  const plain = typeof doc?.toObject === "function" ? doc.toObject() : doc || {};
  const id = plain._id ? plain._id.toString() : plain.id;

  return {
    ...plain,
    id,
    _id: undefined,
  };
}

function cleanData(data = {}) {
  const cleaned = { ...data };

  delete cleaned._id;
  delete cleaned.id;
  delete cleaned.collection;
  delete cleaned.data;

  Object.keys(cleaned).forEach((key) => {
    if (cleaned[key] === undefined) delete cleaned[key];
  });

  return cleaned;
}

function cleanCollectionData(collection, data = {}) {
  const cleaned = cleanData(data);
  if (collection === "trips") {
    delete cleaned.preference;
  }
  return cleaned;
}

function addOwnerIfNeeded(collection, data, user) {
  const userId = getUserId(user);

  if (ownedCollections.has(collection) && userId && !data.userId) {
    return { ...data, userId };
  }

  return data;
}

function buildOwnerFilter(collection, user, id = null) {
  const filter = {};

  if (id) filter._id = toObjectId(id);

  if (!isAdmin(user) && !publicCollections.has(collection)) {
    const userId = getUserId(user);
    if (userId) filter.userId = userId;
  }

  return filter;
}

function buildListFilter(req, user) {
  const collection = req.query.collection || req.body.collection;
  const filter = buildOwnerFilter(collection, user);

  if (req.query.category) filter.category = req.query.category;
  if (req.query.status) filter.status = req.query.status;

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

const listData = withAuthAndDb(async ({ req, res, user }) => {
  if (req.method !== "GET") return res.status(405).send("Only GET allowed");

  try {
    const collection = req.query.collection;
    const limit = parseInt(req.query.limit, 10) || 100;

    if (!collection) return res.status(400).json({ error: "Missing collection name" });

    const Model = getModel(collection);
    const data = await Model.find(buildListFilter(req, user))
      .sort({ createdAt: -1, _id: -1 })
      .limit(limit)
      .lean();

    return res.json({
      success: true,
      count: data.length,
      data: data.map(normalizeDoc),
    });
  } catch (err) {
    console.error("listData error:", err);
    return res.status(err.statusCode || 500).json({ error: err.statusCode ? err.message : "Server error" });
  }
});

const createData = withAuthAndDb(async ({ req, res, user }) => {
  if (req.method !== "POST") return res.status(405).send("Only POST allowed");

  try {
    const { collection, data } = parseBody(req);

    if (!collection || !data) return res.status(400).json({ error: "Missing collection or data" });

    const Model = getModel(collection);
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
  if (req.method !== "POST" && req.method !== "PUT") return res.status(405).send("Only POST/PUT allowed");

  try {
    const { collection, id, data } = parseBody(req);

    if (!collection || !id || !data) return res.status(400).json({ error: "Missing collection, id or data" });

    const Model = getModel(collection);
    const cleaned = cleanCollectionData(collection, data);
    delete cleaned.userId;

    const update = { $set: { ...cleaned, updatedAt: new Date() } };
    if (collection === "trips") update.$unset = { preference: "" };

    const doc = await Model.findOneAndUpdate(
      buildOwnerFilter(collection, user, id),
      update,
      { new: true }
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
  if (req.method !== "POST" && req.method !== "DELETE") return res.status(405).send("Only POST/DELETE allowed");

  try {
    const { collection, id } = parseBody(req);

    if (!collection || !id) return res.status(400).json({ error: "Missing collection or id" });

    const Model = getModel(collection);
    const doc = await Model.findOneAndDelete(buildOwnerFilter(collection, user, id));

    let expiredOffers = 0;

    if (doc && collection === "items") {
      expiredOffers = await expireRelatedOffers(db, {
        itemIds: [new ObjectId(id)],
        reason: "Related shipment was deleted",
        actorUid: getUserId(user),
      });
    }

    if (doc && collection === "trips") {
      expiredOffers = await expireRelatedOffers(db, {
        tripIds: [new ObjectId(id)],
        reason: "Related trip was deleted",
        actorUid: getUserId(user),
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

router.all("/listData", listData);
router.all("/createData", createData);
router.all("/updateData", updateData);
router.all("/deleteData", deleteData);

module.exports = router;

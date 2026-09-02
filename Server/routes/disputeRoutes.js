/**
 * Module: Dispute Routes
 * Purpose: Lets users file disputes and lets admins view/update all disputes.
 */
const express = require("express");
const mongoose = require("mongoose");
const { ObjectId } = require("mongodb");
const Dispute = require("../models/Dispute");
const Order = require("../models/Order");
const AccountProfile = require("../models/AccountProfile");
const { getMongoClient } = require("../config/db");
const {
  DISPUTE_WINDOW_MINUTES,
  getDisputeWindowLabel,
  getDisputeDeadline,
  isDisputeWindowOpen,
  findActiveDisputeForOrder,
  getPaymentForOrder,
  getTotalPaidAmount,
  normalizePaymentDecision,
  resolveDisputePayment,
} = require("../utils/disputePaymentUtils");
const {
  protectSession,
  protectTrustedSession,
  requirePlatformAccess: requireRole,
} = require("../middleware/authMiddleware");

const router = express.Router();

function normalizeStatus(value) {
  const raw = String(value || "under_review").toLowerCase().replace(/[\s-]+/g, "_");
  if (["pending", "open", "under_review", "review", "in_review", "investigating", "in_progress", "inprogress"].includes(raw)) return "under_review";
  if (["resolved", "resolve", "solved"].includes(raw)) return "resolved";
  if (["rejected", "declined"].includes(raw)) return "rejected";
  if (["cancelled", "canceled"].includes(raw)) return "cancelled";
  if (["closed"].includes(raw)) return "closed";
  return "under_review";
}

function normalizeText(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function getOrderStatusText(order = {}) {
  return normalizeText(order.status || order.orderStatus || order.deliveryStatus || order.state || "");
}

function isUndeliveredOrder(order = {}) {
  const status = getOrderStatusText(order);
  if (!status) return true;

  const deliveredWords = [
    "received",
    "delivered",
    "completed",
    "complete",
    "done",
    "closed",
    "cancelled",
    "canceled",
    "returned",
    "refunded",
  ];

  return !deliveredWords.some((word) => status.includes(word));
}

function isItemNotDeliveredDispute(natureOfDispute) {
  const nature = normalizeText(natureOfDispute);
  return nature.includes("item not delivered") ||
    nature.includes("not delivered") ||
    nature.includes("not received") ||
    nature.includes("missing item");
}

function isEvidenceRequiredForDispute(natureOfDispute) {
  const nature = normalizeText(natureOfDispute);
  return nature.includes("damaged item") ||
    nature.includes("damage item") ||
    nature.includes("wrong item") ||
    nature.includes("delivery confirmation refused") ||
    nature.includes("wrong delivery details");
}

function hasEvidence(documentURL, evidenceImage) {
  return Boolean(String(documentURL || evidenceImage || "").trim());
}


const FINAL_DISPUTE_STATUSES = ["rejected", "resolved", "cancelled", "closed"];
const ALLOWED_DISPUTE_STATUS_TRANSITIONS = {
  under_review: ["rejected", "resolved"],
};

function isFinalDisputeStatus(status) {
  return FINAL_DISPUTE_STATUSES.includes(normalizeStatus(status));
}

function canMoveDisputeStatus(fromStatus, toStatus) {
  const current = normalizeStatus(fromStatus);
  const next = normalizeStatus(toStatus);
  if (current === next) return true;
  if (isFinalDisputeStatus(current)) return false;
  return (ALLOWED_DISPUTE_STATUS_TRANSITIONS[current] || []).includes(next);
}

function getPaymentFinalStatus(dispute, paymentDecision) {
  const decision = normalizePaymentDecision(paymentDecision);
  const filedByRole = normalizeRole(dispute?.filedByRole || dispute?.viewerRole || dispute?.user?.role || "buyer");

  if (decision === "release_to_traveler") {
    return filedByRole === "traveler" ? "resolved" : "rejected";
  }

  if (decision === "full_refund") {
    return filedByRole === "traveler" ? "rejected" : "resolved";
  }


  return "";
}

function nativeObjectId(value) {
  const text = value && value.toString ? value.toString() : String(value || "");
  if (!ObjectId.isValid(text)) return null;
  return new ObjectId(text);
}

function normalizeRole(value, fallback = "buyer") {
  const raw = String(value || fallback || "buyer").toLowerCase().trim();
  if (["traveler", "traveller"].includes(raw)) return "traveler";
  if (["buyer", "customer", "user"].includes(raw)) return "buyer";
  return fallback || "buyer";
}

function oppositeRole(role) {
  return normalizeRole(role) === "traveler" ? "buyer" : "traveler";
}

function pickText(...values) {
  for (const value of values) {
    if (value === undefined || value === null) continue;
    const text = String(value).trim();
    if (text) return text;
  }
  return "";
}

function toId(value) {
  if (!value) return "";
  return value.toString ? value.toString() : String(value);
}

function toNumber(...values) {
  for (const value of values) {
    if (value === undefined || value === null || value === "") continue;
    const number = Number(value);
    if (Number.isFinite(number)) return number;
  }
  return 0;
}

function objectId(value) {
  const text = String(value || "").trim();
  if (!mongoose.Types.ObjectId.isValid(text)) return null;
  return new mongoose.Types.ObjectId(text);
}

async function findProfileByUid(uid) {
  const text = String(uid || "").trim();
  if (!text) return null;

  const conditions = [{ userId: text }, { uid: text }];
  const mongoId = objectId(text);
  if (mongoId) conditions.push({ _id: mongoId });

  return AccountProfile.findOne({ $or: conditions }).lean();
}

async function findOrderDetails(orderId, orderNumber) {
  const orderText = String(orderId || orderNumber || "").trim();
  const orderNoText = String(orderNumber || orderId || "").trim();

  if (!orderText && !orderNoText) return null;

  const matchOr = [];
  const mongoId = objectId(orderText);
  if (mongoId) matchOr.push({ _id: mongoId });

  [orderText, orderNoText].filter(Boolean).forEach((value) => {
    matchOr.push({ orderId: value }, { orderNumber: value }, { id: value });
  });

  const results = await Order.aggregate([
    { $match: { $or: matchOr } },
    { $lookup: { from: "items", localField: "itemId", foreignField: "_id", as: "item" } },
    { $unwind: { path: "$item", preserveNullAndEmptyArrays: true } },
    { $lookup: { from: "Products", localField: "productId", foreignField: "_id", as: "product" } },
    { $unwind: { path: "$product", preserveNullAndEmptyArrays: true } },
    { $lookup: { from: "profiles", localField: "buyerUid", foreignField: "userId", as: "buyer" } },
    { $unwind: { path: "$buyer", preserveNullAndEmptyArrays: true } },
    { $lookup: { from: "profiles", localField: "travelerUid", foreignField: "userId", as: "traveler" } },
    { $unwind: { path: "$traveler", preserveNullAndEmptyArrays: true } },
    { $lookup: { from: "payments", localField: "paymentId", foreignField: "_id", as: "payment" } },
    { $unwind: { path: "$payment", preserveNullAndEmptyArrays: true } },
    {
      $addFields: {
        itemName: { $ifNull: ["$item.name", "$product.name"] },
        itemImage: { $ifNull: ["$item.image", "$product.image"] },
        productTitle: { $ifNull: ["$product.name", "$item.name"] },
        paymentAmount: "$payment.paymentAmount",
      },
    },
    { $limit: 1 },
  ]);

  return results[0] || null;
}

function buildPerson({ role, uid, profile, order, fallbackName = "", fallbackEmail = "" }) {
  const normalizedRole = normalizeRole(role);
  const source = normalizedRole === "traveler" ? order?.traveler : order?.buyer;

  return {
    id: pickText(uid, profile?.userId, profile?.uid, source?.userId, source?.uid, source?._id),
    name: pickText(profile?.name, source?.name, fallbackName, normalizedRole === "traveler" ? "Traveler" : "Buyer"),
    email: pickText(profile?.email, source?.email, fallbackEmail, ""),
    role: normalizedRole,
  };
}

async function buildDisputeDetails(rawDispute = {}, requestUser = null) {
  const raw = rawDispute.toObject ? rawDispute.toObject() : rawDispute;
  const order = await findOrderDetails(raw.orderId, raw.orderNumber);

  const filedByRole = normalizeRole(raw.filedByRole || raw.viewerRole || raw.user?.role || raw.role || "buyer");
  const againstRole = normalizeRole(raw.againstRole || oppositeRole(filedByRole), oppositeRole(filedByRole));

  const buyerUid = pickText(raw.buyerUid, order?.buyerUid, order?.buyer?.userId, order?.buyer?.uid);
  const travelerUid = pickText(raw.travelerUid, order?.travelerUid, order?.traveler?.userId, order?.traveler?.uid);

  const filedUid = filedByRole === "traveler" ? travelerUid : buyerUid;
  const againstUid = againstRole === "traveler" ? travelerUid : buyerUid;

  const [filedProfile, againstProfile] = await Promise.all([
    findProfileByUid(pickText(raw.userId, raw.user?.id, filedUid, requestUser?.userId, requestUser?.uid)),
    findProfileByUid(pickText(raw.againstId, raw.againstUserId, raw.filedAgainst?.id, raw.againstUser?.id, againstUid)),
  ]);

  const userName = pickText(raw.userName, raw.user?.name, requestUser?.name, requestUser?.email, filedProfile?.name);
  const userEmail = pickText(raw.userEmail, raw.user?.email, requestUser?.email, filedProfile?.email);

  const filedBy = buildPerson({
    role: filedByRole,
    uid: pickText(raw.userId, raw.user?.id, filedUid, requestUser?.userId, requestUser?.uid),
    profile: filedProfile,
    order,
    fallbackName: userName,
    fallbackEmail: userEmail,
  });

  const filedAgainst = buildPerson({
    role: againstRole,
    uid: againstUid,
    profile: againstProfile,
    order,
    fallbackName: pickText(raw.againstName, raw.againstUserName, raw.filedAgainst?.name, raw.againstUser?.name),
    fallbackEmail: pickText(raw.againstEmail, raw.againstUserEmail, raw.filedAgainst?.email, raw.againstUser?.email),
  });

  const productId = pickText(
    raw.productId,
    raw.itemId,
    order?.productId,
    order?.itemId,
    order?.product?._id,
    order?.item?._id
  );

  const itemImage = pickText(
    raw.itemImage,
    raw.productImage,
    order?.itemImage,
    order?.item?.image,
    order?.product?.image,
    order?.product?.imageUrl
  );

  const totalCostPaid = toNumber(
    order?.payment?.paymentAmount,
    order?.paymentAmount,
    order?.totalPaid,
    order?.totalCostPaid,
    raw.totalPaid,
    raw.totalCostPaid,
    raw.totalPrice,
    raw.totalAmount,
    order?.totalPrice,
    order?.totalAmount
  );

  const reward = toNumber(
    raw.reward,
    raw.travelerReward,
    raw.offeredReward,
    order?.reward,
    order?.travelerReward,
    order?.offeredReward
  );

  return {
    order,
    filedBy,
    filedAgainst,
    filedByRole,
    againstRole,
    buyerUid,
    travelerUid,
    productId: toId(productId),
    itemId: toId(productId),
    itemImage,
    productImage: itemImage,
    totalCostPaid,
    totalPaid: totalCostPaid,
    totalPrice: totalCostPaid,
    totalAmount: totalCostPaid,
    reward,
    travelerReward: reward,
  };
}

async function toDisputeResponse(dispute = {}) {
  const raw = dispute.toObject ? dispute.toObject() : dispute;
  const id = raw._id?.toString?.() || raw.id || "";
  const details = await buildDisputeDetails(raw);

  const response = {
    ...raw,
    _id: id,
    id,
    status: normalizeStatus(raw.status),
    orderId: pickText(raw.orderId, details.order?._id, raw.orderNumber),
    orderNumber: pickText(raw.orderNumber, raw.orderId, details.order?._id),
    productId: details.productId,
    itemId: details.itemId,
    itemImage: details.itemImage,
    productImage: details.productImage,
    totalCostPaid: details.totalCostPaid || raw.totalCostPaid || 0,
    totalPaid: details.totalPaid || raw.totalPaid || raw.totalCostPaid || 0,
    totalPrice: details.totalPrice || raw.totalPrice || raw.totalCostPaid || 0,
    totalAmount: details.totalAmount || raw.totalAmount || raw.totalCostPaid || 0,
    reward: details.reward,
    travelerReward: details.travelerReward,
    filedByRole: details.filedByRole,
    againstRole: details.againstRole,
    buyerUid: details.buyerUid,
    travelerUid: details.travelerUid,
    filedBy: details.filedBy,
    filedAgainst: details.filedAgainst,
    againstUser: details.filedAgainst,
    againstId: details.filedAgainst.id,
    againstName: details.filedAgainst.name,
    againstEmail: details.filedAgainst.email,
    user: raw.user || {
      id: raw.userId || details.filedBy.id || "",
      name: raw.userName || details.filedBy.name || "User",
      email: raw.userEmail || details.filedBy.email || "",
      role: details.filedBy.role,
    },
    buyerName: details.filedByRole === "buyer" ? details.filedBy.name : details.filedAgainst.name,
    buyerEmail: details.filedByRole === "buyer" ? details.filedBy.email : details.filedAgainst.email,
    travelerName: details.filedByRole === "traveler" ? details.filedBy.name : details.filedAgainst.name,
    travelerEmail: details.filedByRole === "traveler" ? details.filedBy.email : details.filedAgainst.email,
    paymentStatus: details.order?.payment?.paymentStatus || raw.paymentStatus || "",
    travelerPaymentStatus: details.order?.payment?.travelerPaymentStatus || raw.travelerPaymentStatus || "",
    paymentReleaseEligibleAt: details.order?.payment?.paymentReleaseEligibleAt || details.order?.paymentReleaseEligibleAt || raw.paymentReleaseEligibleAt || "",
    disputeWindowEndsAt: details.order?.disputeWindowEndsAt || raw.disputeWindowEndsAt || "",
    disputeWindowMinutes: details.order?.disputeWindowMinutes || raw.disputeWindowMinutes || DISPUTE_WINDOW_MINUTES,
    paymentOutcome: details.order?.paymentOutcome || raw.paymentOutcome || "",
    paymentDecision: raw.paymentDecision || "",
    refundAmount: raw.refundAmount || details.order?.payment?.refundAmount || 0,
    travelerReleaseAmount: raw.travelerReleaseAmount || details.order?.payment?.stripeTransferAmount || 0,
    adminNote: raw.adminNote || "",
  };

  return response;
}

router.post("/", protectSession, async (req, res) => {
  try {
    const userId = req.user?.userId || req.user?.uid || req.user?._id || "";
    const userEmail = req.user?.email || req.firebaseUser?.email || "";
    const userName = req.user?.name || req.firebaseUser?.name || userEmail || "User";

    const {
      orderId,
      orderNumber,
      natureOfDispute,
      itemDescription,
      extraDetails,
      documentURL,
      evidenceImage,
      filedByRole,
      againstRole,
      buyerUid,
      travelerUid,
      viewerRole,
      productId,
      itemId,
      itemImage,
      productImage,
      totalCostPaid,
      totalPaid,
      totalPrice,
      totalAmount,
      reward,
      travelerReward,
    } = req.body || {};

    if (!natureOfDispute || !itemDescription || !extraDetails) {
      return res.status(400).json({ message: "Please fill all required dispute fields" });
    }

    if (isEvidenceRequiredForDispute(natureOfDispute) && !hasEvidence(documentURL, evidenceImage)) {
      return res.status(400).json({
        message: "Evidence is required for this dispute type",
      });
    }

    const enriched = await buildDisputeDetails({
      orderId: String(orderId || orderNumber || ""),
      orderNumber: String(orderNumber || orderId || ""),
      userId,
      userEmail,
      userName,
      user: { id: userId, name: userName, email: userEmail, role: filedByRole || viewerRole || "" },
      filedByRole: String(filedByRole || viewerRole || ""),
      againstRole: String(againstRole || ""),
      buyerUid: String(buyerUid || ""),
      travelerUid: String(travelerUid || ""),
      productId: String(productId || itemId || ""),
      itemId: String(itemId || productId || ""),
      itemImage: String(itemImage || productImage || ""),
      productImage: String(productImage || itemImage || ""),
      totalCostPaid,
      totalPaid,
      totalPrice,
      totalAmount,
      reward,
      travelerReward,
    }, req.user);

    const nativeClient = await getMongoClient();
    const db = nativeClient.db("myDatabase");
    const order = enriched.order;

    if (!order) {
      return res.status(404).json({ message: "Order not found for dispute" });
    }

    const payment = await getPaymentForOrder(db, order);
    if (!payment) {
      return res.status(400).json({ message: "Payment record not found for this order" });
    }

    const actualRole = userId === enriched.travelerUid ? "traveler" : userId === enriched.buyerUid ? "buyer" : enriched.filedByRole;
    const filedByPerson = actualRole === enriched.filedByRole ? enriched.filedBy : enriched.filedAgainst;
    const filedAgainstPerson = actualRole === enriched.filedByRole ? enriched.filedAgainst : enriched.filedBy;

    if (userId !== enriched.buyerUid && userId !== enriched.travelerUid) {
      return res.status(403).json({ message: "You can file dispute only for your own buyer/traveler order" });
    }

    // Placed/in-transit/undelivered orders can be disputed anytime.
    // The dispute deadline is enforced only after delivery/confirmation.
    const canFileUndeliveredWithoutTimeLimit = isUndeliveredOrder(order);

    if (!isDisputeWindowOpen(order) && !canFileUndeliveredWithoutTimeLimit) {
      const deadline = getDisputeDeadline(order);
      return res.status(409).json({
        message: `Dispute time is over. You can file a dispute only within ${getDisputeWindowLabel()} after delivery confirmation.`,
        disputeWindowMinutes: DISPUTE_WINDOW_MINUTES,
        disputeWindowEndsAt: deadline,
      });
    }

    const orderIdForDisputeCheck = order._id?.toString?.() || String(orderId || orderNumber || "");
    const existingSameRoleDispute = await db.collection("disputes").findOne({
      orderId: orderIdForDisputeCheck,
      $or: [
        { filedByRole: actualRole },
        { viewerRole: actualRole },
        { "user.role": actualRole },
        { userId },
        { "user.id": userId },
      ],
    });

    if (existingSameRoleDispute) {
      return res.status(409).json({
        message: `A ${actualRole} dispute already exists for this order`,
      });
    }

    const now = new Date();
    const normalizedOrderId = order._id?.toString?.() || String(orderId || orderNumber || "");
    const normalizedOrderNumber = String(orderNumber || orderId || normalizedOrderId || "");

    const dispute = await Dispute.create({
      orderId: normalizedOrderId,
      orderNumber: normalizedOrderNumber,
      productId: String(productId || itemId || enriched.productId || ""),
      itemId: String(itemId || productId || enriched.itemId || ""),
      itemImage: String(itemImage || productImage || enriched.itemImage || ""),
      productImage: String(productImage || itemImage || enriched.productImage || ""),
      totalCostPaid: toNumber(totalCostPaid, totalPaid, totalPrice, totalAmount, enriched.totalCostPaid),
      totalPaid: toNumber(totalPaid, totalCostPaid, totalPrice, totalAmount, enriched.totalCostPaid),
      totalPrice: toNumber(totalPrice, totalCostPaid, totalPaid, totalAmount, enriched.totalCostPaid),
      totalAmount: toNumber(totalAmount, totalCostPaid, totalPaid, totalPrice, enriched.totalCostPaid),
      reward: toNumber(reward, travelerReward, enriched.reward),
      travelerReward: toNumber(travelerReward, reward, enriched.reward),
      userId,
      userEmail,
      userName,
      user: { id: userId, name: userName, email: userEmail, role: actualRole },
      filedBy: filedByPerson,
      filedAgainst: filedAgainstPerson,
      againstUser: filedAgainstPerson,
      againstId: filedAgainstPerson.id,
      againstName: filedAgainstPerson.name,
      againstEmail: filedAgainstPerson.email,
      filedByRole: actualRole,
      againstRole: oppositeRole(actualRole),
      buyerUid: enriched.buyerUid,
      travelerUid: enriched.travelerUid,
      buyerName: actualRole === "buyer" ? filedByPerson.name : filedAgainstPerson.name,
      buyerEmail: actualRole === "buyer" ? filedByPerson.email : filedAgainstPerson.email,
      travelerName: actualRole === "traveler" ? filedByPerson.name : filedAgainstPerson.name,
      travelerEmail: actualRole === "traveler" ? filedByPerson.email : filedAgainstPerson.email,
      natureOfDispute: String(natureOfDispute || ""),
      itemDescription: String(itemDescription || ""),
      extraDetails: String(extraDetails || ""),
      documentURL: String(documentURL || evidenceImage || ""),
      evidenceImage: String(evidenceImage || documentURL || ""),
      viewerRole: actualRole,
      paymentStatus: payment.paymentStatus || "",
      travelerPaymentStatus: "DISPUTED",
      paymentReleaseEligibleAt: order.paymentReleaseEligibleAt || payment.paymentReleaseEligibleAt || null,
      disputeWindowEndsAt: order.disputeWindowEndsAt || null,
      disputeWindowMinutes: DISPUTE_WINDOW_MINUTES,
      status: "under_review",
    });

    const orderNativeId = nativeObjectId(order._id);
    const paymentNativeId = nativeObjectId(payment._id);
    await Promise.all([
      paymentNativeId
        ? db.collection("payments").updateOne(
          { _id: paymentNativeId },
          {
            $set: { travelerPaymentStatus: "DISPUTED", disputeId: dispute._id.toString(), disputedAt: now, updatedAt: now },
            $addToSet: { disputeIds: dispute._id.toString() },
          }
        )
        : Promise.resolve(),
      orderNativeId
        ? db.collection("orders").updateOne(
          { _id: orderNativeId },
          {
            $set: { paymentOutcome: "DISPUTED", disputeId: dispute._id.toString(), disputedAt: now, updatedAt: now },
            $addToSet: { disputeIds: dispute._id.toString() },
            $push: { statusHistory: { status: order.status || "Received", by: userId || userEmail || "user", note: "Dispute filed. Payment frozen until admin decision.", at: now } },
          }
        )
        : Promise.resolve(),
    ]);

    return res.status(201).json({ success: true, dispute: await toDisputeResponse(dispute) });
  } catch (error) {
    console.error("Create dispute error:", error.message);
    return res.status(500).json({ message: "Could not create dispute" });
  }
});

router.get("/my", protectSession, async (req, res) => {
  try {
    const userId = req.user?.userId || req.user?.uid || req.user?._id || "";
    const email = req.user?.email || req.firebaseUser?.email || "";
    const normalizedEmail = String(email || "").trim().toLowerCase();

    const ownershipFilters = [];

    if (userId) {
      ownershipFilters.push(
        { userId },
        { "user.id": userId },
        { "filedBy.id": userId }
      );
    }

    if (normalizedEmail) {
      ownershipFilters.push(
        { userEmail: normalizedEmail },
        { "user.email": normalizedEmail },
        { "filedBy.email": normalizedEmail },
        { userEmail: email },
        { "user.email": email },
        { "filedBy.email": email }
      );
    }

    if (!ownershipFilters.length) {
      return res.json({ success: true, disputes: [] });
    }

    // Only show disputes filed by the signed-in user.
    // Do not include buyerUid, travelerUid, filedAgainst, or againstId here,
    // because both sides may file separate disputes for the same order.
    // A buyer-filed dispute should stay hidden from the traveler dashboard,
    // and a traveler-filed dispute should stay hidden from the buyer dashboard.
    const disputes = await Dispute.find({ $or: ownershipFilters })
      .sort({ createdAt: -1, _id: -1 })
      .lean();

    const data = await Promise.all(disputes.map(toDisputeResponse));
    return res.json({ success: true, disputes: data });
  } catch (error) {
    console.error("My disputes error:", error.message);
    return res.status(500).json({ message: "Could not load disputes" });
  }
});

router.post("/:id/cancel", protectSession, async (req, res) => {
  try {
    const userId = req.user?.userId || req.user?.uid || req.user?._id || "";
    const email = req.user?.email || req.firebaseUser?.email || "";

    const dispute = await Dispute.findById(req.params.id);

    if (!dispute) return res.status(404).json({ message: "Dispute not found" });

    const raw = dispute.toObject ? dispute.toObject() : dispute;
    const belongsToUser =
      raw.userId === userId ||
      raw.user?.id === userId ||
      raw.userEmail === email ||
      raw.user?.email === email;

    if (!belongsToUser) {
      return res.status(403).json({ message: "You can cancel only your own dispute" });
    }

    const currentStatus = normalizeStatus(raw.status);

    if (currentStatus !== "under_review") {
      return res.status(409).json({ message: "Closed disputes cannot be cancelled" });
    }

    dispute.status = "cancelled";
    dispute.cancelledAt = new Date();
    dispute.cancelledBy = userId || email || "user";
    dispute.updatedAt = new Date();

    await dispute.save();

    return res.json({ success: true, dispute: await toDisputeResponse(dispute) });
  } catch (error) {
    console.error("Cancel dispute error:", error.message);
    return res.status(500).json({ message: "Could not cancel dispute" });
  }
});

router.get("/", protectTrustedSession, requireRole, async (req, res) => {
  try {
    const disputes = await Dispute.find({}).sort({ createdAt: -1, _id: -1 }).lean();
    const data = await Promise.all(disputes.map(toDisputeResponse));
    return res.json({ success: true, disputes: data });
  } catch (error) {
    console.error("Admin disputes error:", error.message);
    return res.status(500).json({ message: "Could not load disputes" });
  }
});

router.put("/:id/status", protectTrustedSession, requireRole, async (req, res) => {
  try {
    let status = normalizeStatus(req.body?.status);
    const manualPartialRefundConfirmed = req.body?.manualPartialRefundConfirmed === true;
    const adminNote = String(req.body?.adminNote || "").trim();
    const dispute = await Dispute.findById(req.params.id);

    if (!dispute) return res.status(404).json({ message: "Dispute not found" });

    if (manualPartialRefundConfirmed) {
      status = "resolved";
    }

    const currentStatus = normalizeStatus(dispute.status);

    if (!canMoveDisputeStatus(currentStatus, status)) {
      return res.status(409).json({
        message: `Invalid dispute status change: ${currentStatus} cannot be changed to ${status}`,
        currentStatus,
        requestedStatus: status,
      });
    }

    let updatedDispute = dispute;
    const adminActor = req.user?.email || req.user?.userId || "admin";

    if (currentStatus !== status || manualPartialRefundConfirmed || adminNote) {
      const changedAt = new Date();
      const historyDecision = manualPartialRefundConfirmed
        ? "manual_stripe_done"
        : "status_only";

      const updateSet = {
        status,
        statusChangedAt: changedAt,
        adminUpdatedBy: adminActor,
        adminNote: adminNote || dispute.adminNote || "",
        updatedAt: changedAt,
      };

      if (manualPartialRefundConfirmed) {
        updateSet.manualPartialRefundConfirmed = true;
        updateSet.manualPartialRefundConfirmedAt = changedAt;
        updateSet.paymentDecision = "manual_stripe_done";
        updateSet.paymentActionResult = {
          manual: true,
          action: "manual_stripe_done",
          status: "confirmed",
          note: "Manual Stripe Sandbox partial refund completed by admin.",
        };
      }

      updatedDispute = await Dispute.findByIdAndUpdate(
        req.params.id,
        {
          $set: updateSet,
          $push: {
            adminStatusHistory: {
              from: currentStatus,
              to: status,
              paymentDecision: historyDecision,
              adminNote,
              changedAt,
              changedBy: adminActor,
            },
          },
        },
        { new: true, runValidators: true }
      );

      if (!updatedDispute) return res.status(404).json({ message: "Dispute not found" });
    }

    return res.json({
      success: true,
      dispute: await toDisputeResponse(updatedDispute),
    });
  } catch (error) {
    console.error("Update dispute error:", error.message);
    return res.status(500).json({ message: error.message || "Could not update dispute" });
  }
});

router.post("/:id/payment", protectTrustedSession, requireRole, async (req, res) => {
  try {
    const decision = normalizePaymentDecision(req.body?.paymentDecision || req.body?.action);
    const adminNote = String(req.body?.adminNote || "").trim();

    if (!decision) {
      return res.status(400).json({ message: "Payment decision must be release_to_traveler or full_refund" });
    }


    const dispute = await Dispute.findById(req.params.id);
    if (!dispute) return res.status(404).json({ message: "Dispute not found" });


    const currentStatus = normalizeStatus(dispute.status);
    const finalStatus = getPaymentFinalStatus(dispute, decision);
    if (!finalStatus) {
      return res.status(400).json({ message: "Invalid payment decision" });
    }

    const adminActor = req.user?.email || req.user?.userId || "admin";
    const nativeClient = await getMongoClient();
    const db = nativeClient.db("myDatabase");

    const paymentActionResult = await resolveDisputePayment(db, dispute, decision, {
      adminNote,
      actorUid: adminActor,
      disputeId: dispute._id.toString(),
    });

    const changedAt = new Date();
    const updateSet = {
      status: finalStatus,
      statusChangedAt: changedAt,
      adminUpdatedBy: adminActor,
      adminNote: adminNote || dispute.adminNote || "",
      paymentDecision: decision,
      paymentActionResult,
      updatedAt: changedAt,
    };

    if (decision === "full_refund") {
      updateSet.refundAmount = paymentActionResult?.refund?.amount || 0;
      updateSet.travelerReleaseAmount = 0;
    } else if (decision === "release_to_traveler") {
      updateSet.travelerReleaseAmount = paymentActionResult?.release?.amount || 0;
      updateSet.refundAmount = 0;
    }

    const updatedDispute = await Dispute.findByIdAndUpdate(
      req.params.id,
      {
        $set: updateSet,
        $push: {
          adminStatusHistory: {
            from: currentStatus,
            to: finalStatus,
            paymentDecision: decision,
            adminNote,
            changedAt,
            changedBy: adminActor,
          },
        },
      },
      { new: true, runValidators: true }
    );

    return res.json({
      success: true,
      dispute: await toDisputeResponse(updatedDispute),
      paymentActionResult,
    });
  } catch (error) {
    console.error("Dispute payment action error:", error.message);
    return res.status(500).json({ message: error.message || "Could not process dispute payment" });
  }
});

module.exports = router;

/**
 * Module: Dispute Payment Utils
 * Purpose: Runs real Stripe refund/release actions for dispute decisions before the dispute is finalized.
 */
const { ObjectId } = require("mongodb");
const stripe = require("../config/stripe");
const {
  toStripeCents,
  getStripeCurrency,
  statusHistoryEntry,
  createNotifications,
} = require("./appUtils");

const DISPUTE_WINDOW_MINUTES = Number(process.env.DISPUTE_WINDOW_MINUTES || 24 * 60);
const ACTIVE_DISPUTE_STATUSES = ["pending", "under_review"]; // keep pending only for older saved disputes

function getDisputeWindowLabel() {
  if (DISPUTE_WINDOW_MINUTES % 1440 === 0) {
    const days = DISPUTE_WINDOW_MINUTES / 1440;
    return days === 1 ? "24 hours" : `${days} days`;
  }

  if (DISPUTE_WINDOW_MINUTES % 60 === 0) {
    const hours = DISPUTE_WINDOW_MINUTES / 60;
    return `${hours} hour${hours === 1 ? "" : "s"}`;
  }

  return `${DISPUTE_WINDOW_MINUTES} minute${DISPUTE_WINDOW_MINUTES === 1 ? "" : "s"}`;
}

function getTravelerPaymentHoldStatus() {
  if (DISPUTE_WINDOW_MINUTES === 1440) return "HOLD_24H";
  if (DISPUTE_WINDOW_MINUTES % 60 === 0) return `HOLD_${DISPUTE_WINDOW_MINUTES / 60}H`;
  return `HOLD_${DISPUTE_WINDOW_MINUTES}_MIN`;
}

function nativeObjectId(value) {
  const text = value && value.toString ? value.toString() : String(value || "");
  if (!ObjectId.isValid(text)) return null;
  return new ObjectId(text);
}

function pickText(...values) {
  for (const value of values) {
    if (value === undefined || value === null) continue;
    const text = String(value).trim();
    if (text) return text;
  }
  return "";
}

function firstPositiveNumber(...values) {
  for (const value of values) {
    if (value === undefined || value === null || value === "") continue;
    const number = Number(value);
    if (Number.isFinite(number) && number > 0) return number;
  }
  return 0;
}

function normalizeMoneyAmount(value) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.round(number * 100) / 100 : 0;
}

function getDisputeWindowStart(order = {}) {
  return order.disputeWindowStartedAt || order.deliveryVerifiedAt || order.deliveryConfirmedAt || order.buyerConfirmedAt || order.completedAt || null;
}

function getDisputeDeadline(order = {}) {
  if (order.disputeWindowEndsAt) return new Date(order.disputeWindowEndsAt);
  const start = getDisputeWindowStart(order);
  if (!start) return null;
  return new Date(new Date(start).getTime() + DISPUTE_WINDOW_MINUTES * 60 * 1000);
}

function isDisputeWindowOpen(order = {}) {
  const deadline = getDisputeDeadline(order);
  if (!deadline) return false;
  return new Date() <= deadline;
}

function normalizePaymentDecision(value) {
  const raw = String(value || "").toLowerCase().trim().replace(/[\s-]+/g, "_");
  if (["release", "release_payment", "release_to_traveler", "release_to_traveller", "reject_release"].includes(raw)) return "release_to_traveler";
  if (["full_refund", "refund", "refund_buyer", "refund_to_buyer"].includes(raw)) return "full_refund";
  return "";
}

function getTotalPaidAmount(order = {}, payment = {}) {
  return firstPositiveNumber(
    payment.paymentAmount,
    payment.totalPaid,
    payment.totalCostPaid,
    payment.amountPaid,
    payment.amount,
    order.totalPaid,
    order.totalCostPaid,
    order.paymentAmount,
    order.payment?.paymentAmount,
    order.totalPrice,
    order.totalAmount
  );
}

function getPaymentIntentId(payment = {}) {
  return pickText(
    payment.paymentIntentId,
    payment.stripePaymentIntentId,
    payment.paymentReference,
    payment.paymentMetadata?.paymentIntentId,
    payment.paymentMetadata?.stripePaymentIntentId
  );
}

function getStoredChargeId(payment = {}) {
  const latestCharge = payment.paymentIntent?.latest_charge;
  return pickText(
    payment.stripeChargeId,
    payment.chargeId,
    payment.latestCharge,
    payment.stripeLatestCharge,
    payment.paymentMetadata?.stripeLatestCharge,
    payment.paymentMetadata?.stripeChargeId,
    typeof latestCharge === "string" ? latestCharge : latestCharge?.id
  );
}

async function getChargeIdForPayment(payment = {}) {
  const storedCharge = getStoredChargeId(payment);
  if (storedCharge) return storedCharge;

  const paymentIntentId = getPaymentIntentId(payment);
  if (!paymentIntentId) return "";

  const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId, {
    expand: ["latest_charge"],
  });

  const latestCharge = paymentIntent?.latest_charge;
  return typeof latestCharge === "string" ? latestCharge : latestCharge?.id || "";
}

async function getPaymentForOrder(db, order = {}) {
  const paymentId = nativeObjectId(order.paymentId);
  if (paymentId) {
    const payment = await db.collection("payments").findOne({ _id: paymentId });
    if (payment) return payment;
  }

  const orderIdText = pickText(order._id, order.id, order.orderId, order.orderNumber);
  const orderObjectId = nativeObjectId(orderIdText);
  const orderQueries = [];

  if (orderObjectId) {
    orderQueries.push({ orderId: orderObjectId });
  }

  if (orderIdText) {
    orderQueries.push(
      { orderId: orderIdText },
      { orderNumber: orderIdText },
      { "paymentMetadata.orderId": orderIdText }
    );
  }

  if (!orderQueries.length) return null;
  return db.collection("payments").findOne({ $or: orderQueries });
}

async function findActiveDisputeForOrder(db, orderId, options = {}) {
  const idText = orderId && orderId.toString ? orderId.toString() : String(orderId || "");
  if (!idText) return null;

  const query = {
    orderId: idText,
    status: { $in: ACTIVE_DISPUTE_STATUSES },
  };

  const role = String(options.filedByRole || options.role || "").toLowerCase().trim();
  if (role) {
    query.$or = [
      { filedByRole: role },
      { viewerRole: role },
      { "user.role": role },
    ];
  }

  return db.collection("disputes").findOne(query);
}

async function getTravelerStripeConnect(db, travelerUid) {
  const uid = String(travelerUid || "").trim();
  if (!uid) return null;

  return db.collection("stripeconnect").findOne({
    $or: [
      { userId: uid },
      { uid },
      { travelerUid: uid },
    ],
  });
}

async function releaseTravelerPayment(db, order, payment, options = {}) {
  const now = new Date();
  const orderIdText = order._id?.toString?.() || String(order._id || order.id || "");
  const requestedReleaseAmount = normalizeMoneyAmount(options.releaseAmount || getTotalPaidAmount(order, payment));
  const transferCents = toStripeCents(requestedReleaseAmount);

  if (transferCents <= 0) throw new Error("Invalid traveler release amount");

  const existingRefundAmount = Number(payment.refundAmount || 0);
  if (existingRefundAmount > 0) {
    throw new Error("This payment already has a refund, so the full amount cannot be released");
  }

  if (payment.travelerPaymentStatus === "RELEASED" || payment.stripeTransferId) {
    return {
      skipped: true,
      reason: "already_released",
      release: {
        id: payment.stripeTransferId || "existing_transfer",
        amount: Number(payment.stripeTransferAmount || requestedReleaseAmount || 0),
        currency: payment.stripeTransferCurrency || getStripeCurrency(),
      },
    };
  }

  const stripeConnect = await getTravelerStripeConnect(db, order.travelerUid || payment.travelerUid);
  if (!stripeConnect?.stripeAccountId) {
    throw new Error("Traveler Stripe Connect account is not connected");
  }

  await db.collection("payments").updateOne(
    { _id: payment._id },
    { $set: { travelerPaymentStatus: "PROCESSING", paymentReleaseStartedAt: now, updatedAt: now } }
  );

  let transfer;
  try {
    const sourceTransaction = await getChargeIdForPayment(payment);
    const transferParams = {
      amount: transferCents,
      currency: payment.paymentCurrency || getStripeCurrency(),
      destination: stripeConnect.stripeAccountId,
      transfer_group: `order_${orderIdText}`,
      metadata: {
        orderId: orderIdText,
        disputeId: options.disputeId || "",
        paymentId: payment._id.toString(),
        travelerUid: order.travelerUid || payment.travelerUid || "",
        buyerUid: order.buyerUid || payment.buyerUid || "",
        paymentIntentId: getPaymentIntentId(payment),
        releaseMethod: options.releaseMethod || "DISPUTE_DECISION",
      },
    };

    if (sourceTransaction) {
      transferParams.source_transaction = sourceTransaction;
    }

    transfer = await stripe.transfers.create(transferParams, {
      idempotencyKey: options.idempotencyKey || `dispute_${options.disputeId || orderIdText}_${options.releaseMethod || "release"}_${transferCents}`,
    });
  } catch (error) {
    await db.collection("payments").updateOne(
      { _id: payment._id },
      {
        $set: {
          travelerPaymentStatus: "FAILED",
          travelerPaymentError: error.message || "Stripe transfer failed",
          updatedAt: new Date(),
        },
      }
    );
    throw error;
  }

  const completeTime = new Date();
  const travelerPaymentStatus = options.travelerPaymentStatus || "RELEASED";
  const paymentOutcome = options.paymentOutcome || "RELEASED_TO_TRAVELER";

  await db.collection("payments").updateOne(
    { _id: payment._id },
    {
      $set: {
        travelerPaymentStatus,
        travelerPaidAt: completeTime,
        paymentReleaseMethod: options.releaseMethod || "DISPUTE_DECISION",
        stripeTransferId: transfer.id,
        stripeTransferAmount: transferCents / 100,
        stripeTransferCurrency: transfer.currency || payment.paymentCurrency || getStripeCurrency(),
        updatedAt: completeTime,
      },
      $unset: { travelerPaymentError: "" },
    }
  );

  await db.collection("orders").updateOne(
    { _id: order._id },
    {
      $set: {
        paymentOutcome,
        travelerPaymentReleasedAt: completeTime,
        travelerReleaseAmount: transferCents / 100,
        updatedAt: completeTime,
      },
      $push: {
        statusHistory: statusHistoryEntry(
          order.status || "Received",
          options.actorUid || "system",
          options.note || "Traveler payment released"
        ),
      },
    }
  );

  return {
    release: {
      id: transfer.id,
      amount: transferCents / 100,
      currency: transfer.currency || payment.paymentCurrency || getStripeCurrency(),
      status: "succeeded",
    },
  };
}

async function refundBuyerPayment(db, order, payment, options = {}) {
  const now = new Date();
  const totalPaidAmount = normalizeMoneyAmount(getTotalPaidAmount(order, payment));
  const totalPaidCents = toStripeCents(totalPaidAmount);
  const requestedRefundAmount = normalizeMoneyAmount(options.refundAmount || totalPaidAmount);
  const requestedRefundCents = toStripeCents(requestedRefundAmount);

  if (totalPaidCents <= 0) throw new Error("Invalid total paid amount");
  if (requestedRefundCents <= 0) throw new Error("Invalid refund amount");
  if (requestedRefundCents !== totalPaidCents) throw new Error("Only full refunds are supported in SkyBridge. Use Stripe Sandbox manually for partial refunds.");

  const existingRefundAmount = normalizeMoneyAmount(payment.refundAmount || 0);
  const existingRefundCents = toStripeCents(existingRefundAmount);
  const centsToRefund = Math.max(0, requestedRefundCents - existingRefundCents);

  if (centsToRefund <= 0) {
    return {
      skipped: true,
      reason: "already_refunded",
      refund: {
        id: payment.refundId || "existing_refund",
        amount: existingRefundAmount || requestedRefundAmount,
        currency: payment.refundCurrency || payment.paymentCurrency || getStripeCurrency(),
        status: payment.refundStatus || "succeeded",
      },
    };
  }

  if (payment.stripeTransferId || payment.travelerPaymentStatus === "RELEASED") {
    throw new Error("Traveler payment has already been released, so a new refund cannot be created");
  }

  const paymentIntentId = getPaymentIntentId(payment);
  const chargeId = getStoredChargeId(payment) || (!paymentIntentId ? await getChargeIdForPayment(payment) : "");
  if (!paymentIntentId && !chargeId) throw new Error("Stripe payment intent or charge not found for refund");

  const refundParams = {
    amount: centsToRefund,
    metadata: {
      orderId: order._id?.toString?.() || String(order._id || ""),
      disputeId: options.disputeId || "",
      paymentId: payment._id.toString(),
      reason: options.reason || "DISPUTE_DECISION",
    },
  };

  if (paymentIntentId) {
    refundParams.payment_intent = paymentIntentId;
  } else {
    refundParams.charge = chargeId;
  }

  const refund = await stripe.refunds.create(refundParams, {
    idempotencyKey: options.idempotencyKey || `dispute_${options.disputeId || order._id}_${options.reason || "refund"}_${requestedRefundCents}`,
  });

  const cumulativeRefundCents = existingRefundCents + centsToRefund;
  const cumulativeRefundAmount = cumulativeRefundCents / 100;
  await db.collection("payments").updateOne(
    { _id: payment._id },
    {
      $set: {
        refundStatus: refund.status || "succeeded",
        refundId: refund.id,
        refundAmount: cumulativeRefundAmount,
        refundCurrency: refund.currency || payment.paymentCurrency || getStripeCurrency(),
        refundedAt: now,
        travelerPaymentStatus: "REFUNDED",
        updatedAt: now,
      },
      $addToSet: { stripeRefundIds: refund.id },
    }
  );

  await db.collection("orders").updateOne(
    { _id: order._id },
    {
      $set: {
        paymentOutcome: "REFUNDED_TO_BUYER",
        refundAmount: cumulativeRefundAmount,
        updatedAt: now,
      },
      $push: {
        statusHistory: statusHistoryEntry(
          order.status || "Received",
          options.actorUid || "admin",
          "Buyer fully refunded by admin dispute decision"
        ),
      },
    }
  );

  return {
    refund: {
      id: refund.id,
      amount: cumulativeRefundAmount,
      amountThisAction: centsToRefund / 100,
      currency: refund.currency || payment.paymentCurrency || getStripeCurrency(),
      status: refund.status,
    },
  };
}

async function resolveDisputePayment(db, dispute, paymentDecision, options = {}) {
  const orderObjectId = nativeObjectId(dispute.orderId || dispute.orderNumber);
  const order = orderObjectId ? await db.collection("orders").findOne({ _id: orderObjectId }) : null;
  if (!order) throw new Error("Order not found for dispute payment action");

  const payment = await getPaymentForOrder(db, order);
  if (!payment) throw new Error("Payment not found for dispute payment action");

  const totalPaidAmount = normalizeMoneyAmount(getTotalPaidAmount(order, payment));
  if (totalPaidAmount <= 0) throw new Error("Total paid amount was not found for this order");

  const decision = normalizePaymentDecision(paymentDecision);

  if (decision === "release_to_traveler") {
    return releaseTravelerPayment(db, order, payment, {
      actorUid: options.actorUid,
      disputeId: options.disputeId || dispute._id?.toString?.() || String(dispute._id || ""),
      releaseAmount: totalPaidAmount,
      releaseMethod: "DISPUTE_RELEASE",
      note: options.adminNote || "Dispute decision: total paid amount released to traveler.",
      idempotencyKey: `dispute_${options.disputeId || dispute._id || order._id}_release_${toStripeCents(totalPaidAmount)}`,
    });
  }

  if (decision === "full_refund") {
    return refundBuyerPayment(db, order, payment, {
      actorUid: options.actorUid,
      disputeId: options.disputeId || dispute._id?.toString?.() || String(dispute._id || ""),
      refundAmount: totalPaidAmount,
      reason: "DISPUTE_FULL_REFUND",
      idempotencyKey: `dispute_${options.disputeId || dispute._id || order._id}_full_refund_${toStripeCents(totalPaidAmount)}`,
    });
  }

  throw new Error("Invalid payment decision");
}

async function autoReleaseDisputeWindowPayments(db) {
  const now = new Date();
  const orders = await db.collection("orders").find({
    status: "Received",
    paymentOutcome: "HOLDING_FOR_DISPUTE_WINDOW",
    paymentReleaseEligibleAt: { $lte: now },
  }).limit(20).toArray();

  let checked = 0;
  for (const order of orders) {
    checked += 1;
    const activeDispute = await findActiveDisputeForOrder(db, order._id);
    if (activeDispute) continue;

    const payment = await getPaymentForOrder(db, order);
    if (!payment || payment.travelerPaymentStatus === "RELEASED" || payment.stripeTransferId) continue;

    try {
      await releaseTravelerPayment(db, order, payment, {
        actorUid: "system",
        releaseMethod: "AUTO_AFTER_DISPUTE_WINDOW",
        note: `No dispute filed within ${getDisputeWindowLabel()} window. Traveler payment auto released.`,
      });
      await createNotifications(db, [
        {
          userId: order.buyerUid,
          type: "ORDER_PAYMENT_RELEASED",
          title: "Payment Released",
          message: "The dispute window ended, so payment was released to the traveler.",
          relatedType: "order",
          relatedId: order._id,
          actorUid: "system",
          targetRole: "buyer",
        },
        {
          userId: order.travelerUid,
          type: "TRAVELER_PAYMENT_RELEASED",
          title: "Payment Released",
          message: "The dispute window ended and your payment was released.",
          relatedType: "order",
          relatedId: order._id,
          actorUid: "system",
          targetRole: "traveler",
        },
      ]);
    } catch (error) {
      console.error("Auto release payment failed:", error.message);
    }
  }

  return { checked };
}

module.exports = {
  DISPUTE_WINDOW_MINUTES,
  getDisputeWindowLabel,
  getTravelerPaymentHoldStatus,
  getDisputeDeadline,
  isDisputeWindowOpen,
  findActiveDisputeForOrder,
  getPaymentForOrder,
  getTotalPaidAmount,
  normalizePaymentDecision,
  resolveDisputePayment,
  autoReleaseDisputeWindowPayments,
};

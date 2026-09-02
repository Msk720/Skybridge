/**
 * Module: Dispute Model
 * Purpose: Stores customer dispute reports submitted from the Flutter user app.
 */
const mongoose = require("mongoose");

const disputeUserSchema = new mongoose.Schema(
  {
    id: { type: String, default: "" },
    name: { type: String, default: "" },
    email: { type: String, default: "" },
    role: { type: String, default: "" },
  },
  { _id: false, strict: false }
);

const disputeSchema = new mongoose.Schema(
  {
    orderId: { type: String, default: "" },
    orderNumber: { type: String, default: "" },
    productId: { type: String, default: "" },
    itemId: { type: String, default: "" },
    itemImage: { type: String, default: "" },
    productImage: { type: String, default: "" },
    totalCostPaid: { type: Number, default: 0 },
    totalPaid: { type: Number, default: 0 },
    totalPrice: { type: Number, default: 0 },
    totalAmount: { type: Number, default: 0 },
    reward: { type: Number, default: 0 },
    travelerReward: { type: Number, default: 0 },
    userId: { type: String, default: "" },
    userEmail: { type: String, default: "" },
    userName: { type: String, default: "User" },
    user: {
      id: { type: String, default: "" },
      name: { type: String, default: "User" },
      email: { type: String, default: "" },
      role: { type: String, default: "" },
    },
    filedBy: { type: disputeUserSchema, default: () => ({}) },
    filedAgainst: { type: disputeUserSchema, default: () => ({}) },
    againstUser: { type: disputeUserSchema, default: () => ({}) },
    againstId: { type: String, default: "" },
    againstName: { type: String, default: "" },
    againstEmail: { type: String, default: "" },
    againstRole: { type: String, default: "" },
    filedByRole: { type: String, default: "" },
    buyerUid: { type: String, default: "" },
    travelerUid: { type: String, default: "" },
    buyerName: { type: String, default: "" },
    buyerEmail: { type: String, default: "" },
    travelerName: { type: String, default: "" },
    travelerEmail: { type: String, default: "" },
    natureOfDispute: { type: String, default: "" },
    itemDescription: { type: String, default: "" },
    extraDetails: { type: String, default: "" },
    documentURL: { type: String, default: "" },
    evidenceImage: { type: String, default: "" },
    status: { type: String, default: "under_review" },
    paymentStatus: { type: String, default: "" },
    travelerPaymentStatus: { type: String, default: "" },
    paymentDecision: { type: String, default: "" },
    paymentReleaseEligibleAt: { type: Date, default: null },
    disputeWindowEndsAt: { type: Date, default: null },
    disputeWindowMinutes: { type: Number, default: 1440 },
    refundAmount: { type: Number, default: 0 },
    travelerReleaseAmount: { type: Number, default: 0 },
    adminNote: { type: String, default: "" },
    paymentActionResult: { type: mongoose.Schema.Types.Mixed, default: null },
    adminStatusHistory: { type: [mongoose.Schema.Types.Mixed], default: [] },
  },
  { collection: "disputes", timestamps: true, strict: false }
);

module.exports = mongoose.models.Dispute || mongoose.model("Dispute", disputeSchema);

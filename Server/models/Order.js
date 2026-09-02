/**
 * Module: Unified Models
 * Purpose: Defines or exports MongoDB/Mongoose models used by the unified backend.
 */
const mongoose = require("mongoose");

// SkyBridge orders are stored in the MongoDB collection named "orders".
// strict:false prevents this backend from changing the existing SkyBridge order schema.
const orderSchema = new mongoose.Schema({}, { collection: "orders", strict: false, timestamps: false });

module.exports = mongoose.models.Order || mongoose.model("Order", orderSchema);

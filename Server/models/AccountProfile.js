/**
 * Module: Unified Models
 * Purpose: Defines account profile records stored in the existing profiles collection.
 */
const mongoose = require("mongoose");

const accountProfileSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    uid: { type: String, index: true },
    name: { type: String, default: "", trim: true },
    email: { type: String, default: "", lowercase: true, trim: true, index: true },
    contact: { type: String, default: "" },
    address: { type: String, default: "" },
    profilePicUrl: { type: String, default: "" },
    role: { type: String, default: "user", index: true },
    status: { type: String, default: "active", index: true },
    isBlocked: { type: Boolean, default: false },
    disabled: { type: Boolean, default: false },
  },
  {
    timestamps: true,
    strict: false,
    collection: "profiles",
  }
);

module.exports = mongoose.models.AccountProfile || mongoose.model("AccountProfile", accountProfileSchema);

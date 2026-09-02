/**
 * Module: Unified Models
 * Purpose: Defines or exports MongoDB/Mongoose models used by the unified backend.
 */
const mongoose = require("mongoose");

const contactReplySchema = new mongoose.Schema(
  {
    message: { type: String, required: true, trim: true },
    imageUrl: { type: String, trim: true, default: "" },
    messageType: { type: String, enum: ["text", "image"], default: "text" },
    sender: { type: String, enum: ["admin", "user"], default: "admin" },
  },
  { timestamps: true }
);

const contactMessageSchema = new mongoose.Schema(
  {
    // This is optional now because SkyBridge users may come from profiles/Firebase,
    // not from the old admin dashboard User collection.
    user: { type: mongoose.Schema.Types.Mixed, default: null },

    // SkyBridge/Firebase user id support.
    userId: { type: String, trim: true, default: "" },
    senderId: { type: String, trim: true, default: "" },
    receiverId: { type: String, trim: true, default: "admin" },

    name: { type: String, trim: true, default: "User" },
    email: { type: String, trim: true, default: "Not available" },
    senderName: { type: String, trim: true, default: "" },
    senderEmail: { type: String, trim: true, default: "" },

    subject: { type: String, trim: true, default: "" },
    message: { type: String, required: true, trim: true },
    imageUrl: { type: String, trim: true, default: "" },
    messageType: { type: String, enum: ["text", "image"], default: "text" },
    sender: { type: String, enum: ["admin", "user"], default: "user" },

    // Admin UI treats "new" as unread. Backend also accepts "unread".
    status: {
      type: String,
      enum: ["new", "unread", "read", "seen", "open", "pending", "replied"],
      default: "new",
    },
    isRead: { type: Boolean, default: false },
    replies: [contactReplySchema],
  },
  {
    timestamps: true,
    collection: "contactmessages",
    strict: false,
    autoCreate: false,
    autoIndex: false,
  }
);

module.exports = mongoose.model("ContactMessage", contactMessageSchema);

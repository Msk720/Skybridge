/**
 * Module: Routes
 * Purpose: Handles user messages and replies.
 */
const express = require("express");
const mongoose = require("mongoose");
const Message = require("../models/Message");
const { protectTrustedSession: protect, requirePlatformAccess: requireRole } = require("../middleware/authMiddleware");
const { getMongoClient } = require("../config/db");
const { createNotification } = require("../utils/appUtils");

const router = express.Router();

function normalizeStatus(status, isRead) {
  const value = String(status || "").toLowerCase().replace(/[\s-]+/g, "_");
  if (["replied", "reply_sent"].includes(value)) return "replied";
  if (["read", "seen"].includes(value)) return "read";
  if (["unread", "new", "pending", "open"].includes(value)) return "new";
  if (isRead === false) return "new";
  return value || "new";
}

function normalizeReply(reply) {
  if (!reply) return null;
  return {
    _id: reply._id,
    message: reply.message || reply.reply || reply.text || reply.body || reply.content || "",
    imageUrl: reply.imageUrl || reply.attachmentUrl || reply.fileUrl || "",
    messageType: reply.messageType || (reply.imageUrl || reply.attachmentUrl || reply.fileUrl ? "image" : "text"),
    sender: String(reply.sender || reply.senderRole || reply.from || "admin").toLowerCase().includes("admin") ? "admin" : "user",
    createdAt: reply.createdAt || reply.created_at || reply.date || new Date(),
    updatedAt: reply.updatedAt || reply.updated_at || reply.createdAt || new Date(),
  };
}

function getSenderSide(item = {}) {
  const value = String(item.sender || item.senderRole || item.from || item.role || "user").toLowerCase();
  return value.includes("admin") ? "admin" : "user";
}

function getDbFromClient(client) {
  const dbName = mongoose.connection?.db?.databaseName;
  return dbName ? client.db(dbName) : client.db();
}


function getUserIdFromRequest(req) {
  return String(
    req.user?.uid ||
    req.user?.userId ||
    req.user?._id ||
    req.firebaseUser?.uid ||
    req.firebaseUser?.user_id ||
    req.firebaseUser?.sub ||
    req.body?.userId ||
    req.body?.senderId ||
    ""
  ).trim();
}

function getUserNameFromRequest(req, fallback = "User") {
  return String(
    req.user?.name ||
    req.user?.displayName ||
    req.firebaseUser?.name ||
    req.body?.name ||
    req.body?.senderName ||
    fallback
  ).trim();
}

function getUserEmailFromRequest(req, fallback = "Not available") {
  return String(
    req.user?.email ||
    req.firebaseUser?.email ||
    req.body?.email ||
    req.body?.senderEmail ||
    fallback
  ).trim();
}

function buildChatExistsQuery({ source, userId, receiverId, disputeId }) {
  const chatSource = String(source || "support").toLowerCase();

  if (chatSource === "peer") {
    return {
      source: "peer",
      $or: [
        { senderId: userId, receiverId },
        { senderId: receiverId, receiverId: userId },
      ],
    };
  }

  if (chatSource === "dispute" && disputeId) {
    return { source: "dispute", disputeId };
  }

  return {
    source: chatSource,
    $or: [
      { userId },
      { senderId: userId },
      { receiverId: userId },
    ].filter((condition) => Object.values(condition)[0]),
  };
}

async function notifyChatRecipient({
  userId,
  title,
  message,
  relatedId,
  actorUid = null,
  targetRole = null,
  isNewChat = false,
}) {
  const cleanUserId = String(userId || "").trim();
  if (!cleanUserId || cleanUserId === String(actorUid || "").trim()) return null;

  const client = await getMongoClient();
  const db = getDbFromClient(client);

  return createNotification(db, {
    userId: cleanUserId,
    type: "new_message",
    title: "New Message",
    message: message || "You received a new message.",
    relatedType: "chat",
    relatedId,
    actorUid,
    targetRole,
  });
}

function normalizeMessage(doc, source = "messages", parent = null) {
  const item = typeof doc?.toObject === "function" ? doc.toObject() : doc || {};
  const parentObj = typeof parent?.toObject === "function" ? parent.toObject() : parent || {};

  const name =
    item.name ||
    item.senderName ||
    item.userName ||
    item.fullName ||
    item.user?.name ||
    parentObj.name ||
    parentObj.senderName ||
    parentObj.userName ||
    parentObj.user?.name ||
    "User";

  const email =
    item.email ||
    item.senderEmail ||
    item.userEmail ||
    item.user?.email ||
    parentObj.email ||
    parentObj.senderEmail ||
    parentObj.userEmail ||
    parentObj.user?.email ||
    "No email";

  const userId =
    item.userId ||
    item.senderId ||
    item.uid ||
    item.user ||
    parentObj.userId ||
    parentObj.senderId ||
    parentObj.uid ||
    parentObj.user ||
    "";

  const message = item.message || item.text || item.body || item.content || item.subject || "";
  const replies = Array.isArray(item.replies) ? item.replies.map(normalizeReply).filter(Boolean) : [];

  return {
    ...item,
    _id: item._id,
    source: item.source || source,
    parentId: parentObj._id || item.parentId || null,
    user: item.user || userId || null,
    userId,
    senderId: item.senderId || userId || "",
    receiverId: item.receiverId || parentObj.receiverId || "admin",
    name,
    email,
    senderName: item.senderName || name,
    senderEmail: item.senderEmail || email,
    subject: item.subject || parentObj.subject || "",
    message,
    imageUrl: item.imageUrl || item.attachmentUrl || item.fileUrl || "",
    messageType: item.messageType || (item.imageUrl || item.attachmentUrl || item.fileUrl ? "image" : "text"),
    sender: getSenderSide(item),
    status: normalizeStatus(item.status || parentObj.status, item.isRead ?? parentObj.isRead),
    isRead: item.isRead === true || parentObj.isRead === true || ["read", "replied"].includes(String(item.status || parentObj.status || "").toLowerCase()),
    replies,
    createdAt: item.createdAt || item.created_at || item.date || item.timestamp || parentObj.createdAt || new Date(),
    updatedAt: item.updatedAt || item.updated_at || item.createdAt || parentObj.updatedAt || new Date(),
  };
}

// @route   POST /api/messages
// @desc    Create a user message
// @access  Private
router.post("/", protect, async (req, res) => {
  try {
    const name = getUserNameFromRequest(req);
    const email = getUserEmailFromRequest(req);
    const imageUrl = req.body.imageUrl?.trim() || req.body.attachmentUrl?.trim() || req.body.fileUrl?.trim() || "";
    const messageType = imageUrl ? "image" : "text";
    const message = req.body.message?.trim() || req.body.text?.trim() || req.body.body?.trim() || (imageUrl ? "Image" : "");
    const subject = req.body.subject?.trim() || "";
    const requestedSource = req.body.source?.trim().toLowerCase() || "support";
    const source = ["support", "peer", "dispute"].includes(requestedSource) ? requestedSource : "support";
    const disputeId = req.body.disputeId?.trim() || "";
    const userId = getUserIdFromRequest(req) || req.body.userId || req.body.senderId || "";
    const receiverId = req.body.receiverId?.trim() || (source === "peer" ? "" : "admin");
    const senderRole = req.body.senderRole?.trim().toLowerCase() || "";
    const receiverRole = req.body.receiverRole?.trim().toLowerCase() || "";
    const receiverName = req.body.receiverName?.trim() || req.body.otherUserName?.trim() || "";
    const receiverImage = req.body.receiverImage?.trim() || req.body.otherUserImage?.trim() || "";
    const senderImage = req.body.senderImage?.trim() || req.user?.profilePicUrl || "";

    if (!message && !imageUrl) {
      return res.status(400).json({ message: "Please write a message or select an image." });
    }

    if (source === "peer" && !receiverId) {
      return res.status(400).json({ message: "Receiver is required for chat." });
    }

    const isNewChat = !(await Message.exists(
      buildChatExistsQuery({ source, userId, receiverId: receiverId || "admin", disputeId })
    ));

    const savedMessage = await Message.create({
      user: req.user?._id || userId || null,
      userId,
      senderId: userId,
      receiverId: receiverId || "admin",
      name,
      email,
      senderName: name,
      senderEmail: email,
      senderRole,
      receiverRole,
      receiverName,
      receiverImage,
      senderImage,
      subject,
      message,
      imageUrl,
      messageType,
      sender: "user",
      source,
      disputeId,
      status: "new",
      isRead: false,
      replies: [],
    });

    await notifyChatRecipient({
      userId: source === "peer" ? receiverId : "admin",
      title: "New Message",
      message: imageUrl ? `${name} sent an image.` : `${name} sent a message.`,
      relatedId: savedMessage._id,
      actorUid: userId,
      targetRole: source === "peer" ? receiverRole : "admin",
      isNewChat,
    });

    return res.status(201).json(normalizeMessage(savedMessage, "messages"));
  } catch (error) {
    console.error("Create message error:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
});

router.post("/admin/start", protect, async (req, res) => {
  try {
    const {
      userId = "",
      name = "User",
      email = "",
      message = "Admin opened chat from dispute case.",
      source = "dispute",
      disputeId = "",
    } = req.body || {};

    const chatSource = ["support", "dispute"].includes(String(source).toLowerCase())
      ? String(source).toLowerCase()
      : "dispute";

    if (!userId && !email && !name) {
      return res.status(400).json({
        message: "User information is required to start chat",
      });
    }

    const isNewChat = !(await Message.exists(
      buildChatExistsQuery({ source: chatSource, userId: userId || email || name, receiverId: "admin", disputeId })
    ));

    const savedMessage = await Message.create({
      user: userId || null,
      userId,
      senderId: "admin",
      receiverId: userId || email || name,
      name,
      email,
      senderName: "Admin",
      senderEmail: "admin",
      subject: chatSource === "dispute" ? "Dispute Messages" : "Admin Messages",
      message,
      sender: "admin",
      status: "replied",
      isRead: true,
      source: chatSource,
      disputeId,
      replies: [],
    });

    await notifyChatRecipient({
      userId: userId || email,
      title: "New Message",
      message: "Admin sent you a message.",
      relatedId: savedMessage._id,
      actorUid: "admin",
      targetRole: "buyer",
      isNewChat,
    });

    return res.status(201).json(normalizeMessage(savedMessage, "messages"));
  } catch (error) {
    console.error("Start admin chat error:", error.message);
    return res.status(500).json({
      message: "Could not start chat",
    });
  }
});

// @route   GET /api/messages/my
// @desc    Get current user's messages
// @access  Private
router.get("/my", protect, async (req, res) => {
  try {
    const userId = getUserIdFromRequest(req);
    const userObjectId = req.user?._id;

    const messageQuery = {
      $or: [
        { userId },
        { senderId: userId },
        { receiverId: userId },
        { user: userId },
        ...(userObjectId ? [{ user: userObjectId }] : []),
      ].filter((condition) => Object.values(condition)[0]),
    };

    const messageDocs = await Message.find(messageQuery)
      .sort({ createdAt: -1, _id: -1 })
      .lean();

    const messages = messageDocs
      .map((item) => normalizeMessage(item, "messages"))
      .filter((item) => item.message)
      .sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));

    return res.json(messages);
  } catch (error) {
    console.error("My messages error:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
});

// @route   GET /api/messages/admin
// @desc    Get all messages for the platform dashboard
// @access  Protected platform
router.get("/admin", protect, requireRole, async (req, res) => {
  try {
    const messageDocs = await Message.find()
      .sort({ createdAt: -1, _id: -1 })
      .lean();

    const seen = new Set();
    const messages = messageDocs
      .map((item) => normalizeMessage(item, "messages"))
      .filter((item) => {
        const key = `${item.source}:${item.parentId || ""}:${item._id || ""}:${item.message}`;
        if (!item.message || seen.has(key)) return false;
        seen.add(key);
        return true;
      })
      .sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));

    return res.json(messages);
  } catch (error) {
    console.error("Messages error:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
});

// @route   POST /api/messages/:id/reply
// @desc    Reply to a message
// @access  Protected platform
router.post("/:id/reply", protect, requireRole, async (req, res) => {
  try {
    const imageUrl = req.body.imageUrl?.trim() || req.body.attachmentUrl?.trim() || req.body.fileUrl?.trim() || "";
    const reply = req.body.reply?.trim() || req.body.message?.trim() || (imageUrl ? "Image" : "");
    const messageType = imageUrl ? "image" : "text";
    if (!reply && !imageUrl) {
      return res.status(400).json({ message: "Reply message or image is required." });
    }

    const replyItem = {
      message: reply,
      imageUrl,
      messageType,
      sender: "admin",
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    let updated = await Message.findByIdAndUpdate(
      req.params.id,
      {
        $push: { replies: replyItem },
        $set: { status: "replied", isRead: true, updatedAt: new Date() },
      },
      { new: true }
    ).lean();

    if (updated) {
      const userKey = updated.userId || updated.senderId || updated.user || updated.email;
      if (userKey) {
        await notifyChatRecipient({
          userId: userKey,
          title: "New Message",
          message: imageUrl ? "Admin sent you an image." : "Admin replied to your message.",
          relatedId: updated._id,
          actorUid: "admin",
          targetRole: "buyer",
          isNewChat: false,
        });

        await Message.updateMany(
          {
            _id: { $ne: updated._id },
            $or: [{ userId: userKey }, { senderId: userKey }, { user: userKey }, { email: userKey }],
          },
          { $set: { status: "replied", isRead: true } }
        );
      }
      return res.json(normalizeMessage(updated, "messages"));
    }

    return res.status(404).json({ message: "Message not found" });
  } catch (error) {
    console.error("Reply message error:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
});

module.exports = router;

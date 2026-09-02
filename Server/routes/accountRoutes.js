/**
 * Module: Routes
 * Purpose: Handles account/profile management routes.
 */
const express = require("express");
const bcrypt = require("bcryptjs");
const Account = require("../models/Account");
const { protectTrustedSession: protect, requirePlatformAccess: requireRole } = require("../middleware/authMiddleware");
const {
  AccountProfile,
  findProfileById,
  toAccountResponse,
  normalizeRole,
  normalizeStatus,
  createFirebaseAccount,
  updateFirebaseAccount,
  updateFirebaseRole,
  getFirebaseAccount,
  deleteFirebaseAccount,
} = require("../utils/accountUtils");

const router = express.Router();

function getStatusFromBody(body) {
  if (body.status === undefined) {
    return null;
  }

  return String(body.status).trim().toLowerCase() === "blocked"
    ? "blocked"
    : "active";
}

async function hydrateProfile(profile) {
  const firebaseAccount = await getFirebaseAccount(profile.userId || profile.uid);
  return toAccountResponse(profile, firebaseAccount);
}

async function syncAccount({ email, previousEmail, name, password, role }) {
  if (!email) return null;

  const updates = { email, updatedAt: new Date() };
  if (name) updates.name = name;
  if (role) updates.role = role;
  if (password) updates.password = await bcrypt.hash(password, 10);

  const query = previousEmail ? { email: previousEmail } : { email };
  return Account.findOneAndUpdate(
    query,
    { $set: updates, $setOnInsert: { createdAt: new Date() } },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
}

// @route   GET /api/accounts
// @desc    Get all accounts from profiles collection
// @access  Protected platform
router.get("/", protect, requireRole, async (req, res) => {
  try {
    const search = (req.query.search || "").trim();
    const role = req.query.role ? normalizeRole(req.query.role) : null;
    const status = req.query.status ? String(req.query.status).toLowerCase() : null;

    const filter = {};

    if (search) {
      filter.$or = [
        { name: { $regex: search, $options: "i" } },
        { email: { $regex: search, $options: "i" } },
        { userId: { $regex: search, $options: "i" } },
      ];
    }

    if (role) {
      filter.role = role;
    }

    if (status === "active") {
      filter.$and = [
        ...(filter.$and || []),
        {
          $or: [
            { status: "active" },
            { status: { $exists: false } },
            { status: null },
          ],
        },
      ];
    }

    if (status === "blocked") {
      filter.status = "blocked";
    }

    const profiles = await AccountProfile.find(filter).sort({ createdAt: -1 });
    const users = await Promise.all(profiles.map(hydrateProfile));

    return res.json({ count: users.length, users, accounts: users });
  } catch (error) {
    console.error("Account list error:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
});

// @route   GET /api/accounts/:id
// @desc    Get one account profile
// @access  Protected platform
router.get("/:id", protect, requireRole, async (req, res) => {
  try {
    const profile = await findProfileById(req.params.id);
    if (!profile) {
      return res.status(404).json({ message: "account not found" });
    }

    const user = await hydrateProfile(profile);
    return res.json({ user });
  } catch (error) {
    console.error("Account detail error:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
});

// @route   POST /api/accounts
// @desc    Create Firebase account and matching profile
// @access  Protected platform
router.post("/", protect, requireRole, async (req, res) => {
  try {
    const name = req.body.name?.trim();
    const email = req.body.email?.trim().toLowerCase();
    const password = req.body.password || "Password123!";
    const role = normalizeRole(req.body.role);

    if (!name || !email || !password) {
      return res.status(400).json({ message: "Name, email and password are required" });
    }

    const firebaseAccount = await createFirebaseAccount({ email, password, name, role });

    const profile = await AccountProfile.findOneAndUpdate(
      { userId: firebaseAccount.uid },
      {
        $set: {
          userId: firebaseAccount.uid,
          uid: firebaseAccount.uid,
          name,
          email,
          role,
          status: "active",
          updatedAt: new Date(),

        },
        $setOnInsert: { createdAt: new Date() },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    await syncAccount({ email, name, password, role });

    return res.status(201).json({
      message: "account created successfully",
      user: toAccountResponse(profile, firebaseAccount),
      account: toAccountResponse(profile, firebaseAccount),
    });
  } catch (error) {
    console.error("Account create error:", error.message);
    return res.status(500).json({ message: error.message || "Server error" });
  }
});

// @route   PUT /api/accounts/:id
// @desc    Update role/status/profile for a account
// @access  Protected platform
router.put("/:id", protect, requireRole, async (req, res) => {
  try {
    const profile = await findProfileById(req.params.id);

    if (!profile) {
      return res.status(404).json({ message: "account not found" });
    }

    const previousEmail = profile.email;
    const role = req.body.role !== undefined ? normalizeRole(req.body.role) : profile.role;
    const status = getStatusFromBody(req.body);

    if (req.body.name !== undefined) {
      profile.name = req.body.name.trim();
    }

    if (req.body.email !== undefined) {
      profile.email = req.body.email.trim().toLowerCase();
    }

    if (req.body.role !== undefined) {
      profile.role = role;
    }

    if (status) {
      profile.status = status;
    }

    profile.updatedAt = new Date();
    await profile.save();

    const uid = profile.userId || profile.uid;

    await updateFirebaseAccount(uid, {
      name: profile.name,
      email: profile.email,
      password: req.body.password,
    });

    if (req.body.role !== undefined) {
      await updateFirebaseRole(uid, role);
    }

    const firebaseAccount = await getFirebaseAccount(uid);
    await syncAccount({
      previousEmail,
      email: profile.email,
      name: profile.name,
      password: req.body.password,
      role,
    });

    return res.json({
      message: "account updated successfully",
      user: toAccountResponse(profile, firebaseAccount),
      account: toAccountResponse(profile, firebaseAccount),
    });
  } catch (error) {
    console.error("Account update error:", error.message);
    return res.status(500).json({ message: error.message || "Server error" });
  }
});

// @route   PATCH /api/accounts/:id/status
// @desc    Block/unblock account
// @access  Protected platform
router.patch("/:id/status", protect, requireRole, async (req, res) => {
  try {
    const profile = await findProfileById(req.params.id);

    if (!profile) {
      return res.status(404).json({ message: "account not found" });
    }

    const status = getStatusFromBody(req.body);

    if (!status) {
      return res.status(400).json({ message: "Account status is required" });
    }

    profile.status = status;
    profile.updatedAt = new Date();
    await profile.save();

    const uid = profile.userId || profile.uid;
    const firebaseAccount = await getFirebaseAccount(uid);

    return res.json({
      message: status === "blocked" ? "account blocked successfully" : "account unblocked successfully",
      user: toAccountResponse(profile, firebaseAccount),
      account: toAccountResponse(profile, firebaseAccount),
    });
  } catch (error) {
    console.error("Account status update error:", error.message);
    return res.status(500).json({ message: error.message || "Server error" });
  }
});
// @route   DELETE /api/accounts/:id
// @desc    Delete profile and matching Firebase account if present
// @access  Protected platform
router.delete("/:id", protect, requireRole, async (req, res) => {
  try {
    const profile = await findProfileById(req.params.id);

    if (!profile) {
      return res.status(404).json({ message: "account not found" });
    }

    const uid = profile.userId || profile.uid;
    const email = profile.email;
    await profile.deleteOne();
    if (email) await Account.deleteOne({ email });

    if (uid) {
      try {
        await deleteFirebaseAccount(uid);
      } catch (firebaseError) {
        console.warn("Firebase user delete skipped:", firebaseError.message);
      }
    }

    return res.json({ message: "account deleted successfully" });
  } catch (error) {
    console.error("Account delete error:", error.message);
    return res.status(500).json({ message: "Server error" });
  }
});


module.exports = router;

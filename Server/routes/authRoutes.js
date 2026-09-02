/**
 * Module: Routes
 * Purpose: Handles account login, registration, and current account lookup.
 */
const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const Account = require("../models/Account");
const { protectTrustedSession, requirePlatformAccess } = require("../middleware/authMiddleware");

const router = express.Router();
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function generateAuthToken(account) {
  if (!process.env.JWT_SECRET) {
    throw new Error("JWT_SECRET is missing");
  }

  return jwt.sign(
    { id: account._id, role: account.role },
    process.env.JWT_SECRET,
    { expiresIn: "7d" }
  );
}

function sanitizeAccount(account) {
  return {
    _id: account._id,
    userId: account._id?.toString?.() || account.userId || account.uid,
    uid: account.uid || account._id?.toString?.(),
    name: account.name,
    email: account.email,
    role: account.role,
  };
}

router.post("/register", async (req, res) => {
  try {
    const name = req.body.name?.trim();
    const email = req.body.email?.trim().toLowerCase();
    const password = req.body.password?.trim();
    const role = req.body.role === "admin" ? "admin" : "user";

    if (!name || !email || !password) return res.status(400).json({ message: "Please fill all fields" });
    if (!EMAIL_REGEX.test(email)) return res.status(400).json({ message: "Please enter a valid email address" });

    const existingAccount = await Account.findOne({ email });
    if (existingAccount) return res.status(400).json({ message: "Email already registered" });

    const hashedPassword = await bcrypt.hash(password, 10);
    const newAccount = await Account.create({ name, email, password: hashedPassword, role });
    const token = generateAuthToken(newAccount);
    return res.status(201).json({
      message: "Account registered successfully",
      token,
      user: sanitizeAccount(newAccount),
    });
  } catch (error) {
    console.error("Register error:", error.message);
    return res.status(500).json({ message: error.message || "Server error" });
  }
});

router.post("/login", async (req, res) => {
  try {
    const email = req.body.email?.trim().toLowerCase();
    const password = req.body.password?.trim();

    if (!email || !password) return res.status(400).json({ message: "Please provide email and password" });

    const account = await Account.findOne({ email });
    if (!account) return res.status(400).json({ message: "Invalid credentials" });

    const isMatch = await bcrypt.compare(password, account.password);
    if (!isMatch) return res.status(400).json({ message: "Invalid credentials" });

    const token = generateAuthToken(account);
    return res.json({ message: "Login successful", token, user: sanitizeAccount(account) });
  } catch (error) {
    console.error("Login error:", error.message);
    return res.status(500).json({ message: error.message || "Server error" });
  }
});

router.get("/me", protectTrustedSession, requirePlatformAccess, async (req, res) => {
  return res.json({ user: req.user });
});

router.get("/check", protectTrustedSession, requirePlatformAccess, async (req, res) => {
  return res.json({ user: req.user, message: "Session verified" });
});

module.exports = router;

/**
 * Module: Unified Utilities
 * Purpose: Provides account/profile lookup, Firebase account sync, and account response helpers.
 */
const mongoose = require("mongoose");
const getFirebaseApp = require("../config/firebase");
const { verifyFirebaseToken } = require("./firebaseToken");
const AccountProfile = require("../models/AccountProfile");

function normalizeRole(value) {
  const role = String(value || "user").trim().toLowerCase();
  return role === "admin" ? "admin" : "user";
}

function normalizeStatus(doc = {}) {
  const rawStatus = String(doc.status || "active").trim().toLowerCase();
  return rawStatus === "blocked" ? "blocked" : "active";
}

function toAccountResponse(profile, firebaseUser = null) {
  const raw = profile?.toObject ? profile.toObject() : profile || {};
  const uid = raw.userId || raw.uid || firebaseUser?.uid || firebaseUser?.user_id || "";
  const email = raw.email || firebaseUser?.email || "";
  const name = raw.name || firebaseUser?.name || firebaseUser?.displayName || email || "Unnamed User";
  const role = normalizeRole(raw.role || firebaseUser?.role || (firebaseUser?.admin ? "admin" : "user"));
  const status = normalizeStatus(raw);

  return {
    _id: raw._id ? raw._id.toString() : uid,
    userId: uid,
    uid,
    name,
    email,
    role,
    status,
    isBlocked: status === "blocked",
    disabled: status === "blocked",
    contact: raw.contact || "",
    address: raw.address || "",
    profilePicUrl: raw.profilePicUrl || "",
    createdAt: raw.createdAt || firebaseUser?.metadata?.creationTime || null,
    updatedAt: raw.updatedAt || null,
  };
}

async function getProfileByFirebaseIdentity(firebaseUser) {
  const uid = firebaseUser.uid || firebaseUser.user_id || firebaseUser.sub;
  const email = String(firebaseUser.email || "").toLowerCase();
  const clauses = [{ userId: uid }, { uid }];
  if (email) clauses.push({ email });

  return AccountProfile.findOne({ $or: clauses });
}

async function findProfileById(id) {
  const clauses = [{ userId: id }, { uid: id }, { email: String(id || "").toLowerCase() }];
  if (mongoose.Types.ObjectId.isValid(id)) clauses.unshift({ _id: id });
  return AccountProfile.findOne({ $or: clauses });
}

function requireFirebaseApp() {
  const firebaseApp = getFirebaseApp();
  if (!firebaseApp) {
    throw new Error("Firebase service account is required for create/update/delete Firebase users");
  }
  return firebaseApp;
}

async function getFirebaseAccount(uid) {
  if (!uid) return null;
  const firebaseApp = getFirebaseApp();
  if (!firebaseApp) return null;

  try {
    return await firebaseApp.auth().getUser(uid);
  } catch {
    return null;
  }
}

async function createFirebaseAccount({ email, password, name, role }) {
  const firebaseApp = requireFirebaseApp();
  const firebaseUser = await firebaseApp.auth().createUser({
    email,
    password,
    displayName: name,
    disabled: false,
  });

  await firebaseApp.auth().setCustomUserClaims(firebaseUser.uid, {
    role: normalizeRole(role),
    admin: normalizeRole(role) === "admin",
  });

  return firebaseUser;
}

async function updateFirebaseAccount(uid, updates = {}) {
  if (!uid) return null;
  const firebaseApp = getFirebaseApp();
  if (!firebaseApp) return null;

  const allowed = {};
  if (updates.email) allowed.email = updates.email;
  if (updates.name) allowed.displayName = updates.name;
  if (updates.password) allowed.password = updates.password;
  if (typeof updates.disabled === "boolean") allowed.disabled = updates.disabled;

  if (!Object.keys(allowed).length) return getFirebaseAccount(uid);
  return firebaseApp.auth().updateUser(uid, allowed);
}

async function updateFirebaseRole(uid, role) {
  if (!uid) return;
  const firebaseApp = getFirebaseApp();
  if (!firebaseApp) return;

  const normalizedRole = normalizeRole(role);
  await firebaseApp.auth().setCustomUserClaims(uid, {
    role: normalizedRole,
    admin: normalizedRole === "admin",
  });
}

async function deleteFirebaseAccount(uid) {
  if (!uid) return;
  const firebaseApp = getFirebaseApp();
  if (!firebaseApp) return;
  await firebaseApp.auth().deleteUser(uid);
}

module.exports = {
  AccountProfile,
  verifyFirebaseToken,
  getProfileByFirebaseIdentity,
  findProfileById,
  toAccountResponse,
  normalizeRole,
  normalizeStatus,
  getFirebaseAccount,
  createFirebaseAccount,
  updateFirebaseAccount,
  updateFirebaseRole,
  deleteFirebaseAccount,
};

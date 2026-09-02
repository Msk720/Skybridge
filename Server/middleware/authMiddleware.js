/**
 * Module: Middleware
 * Purpose: Verifies backend sessions and checks protected access.
 */
const jwt = require("jsonwebtoken");
const Account = require("../models/Account");
const { verifyFirebaseToken: verifyClientFirebaseToken } = require("../utils/firebaseToken");
const {
  verifyFirebaseToken: verifyDirectoryFirebaseToken,
  getProfileByFirebaseIdentity,
  getFirebaseAccount,
  toAccountResponse,
  normalizeStatus,
} = require("../utils/accountUtils");

function getBearerToken(req) {
  const authHeader = req.headers.authorization || "";
  if (!authHeader.startsWith("Bearer ")) return "";
  return authHeader.split(" ")[1];
}

function normalizeAccessRole(value) {
  return String(value || "user").trim().toLowerCase();
}

async function verifyLegacyJwt(token) {
  if (!process.env.JWT_SECRET) return null;

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const account = await Account.findById(decoded.id).select("-password");
    if (!account) return null;

    return {
      source: "jwt",
      account,
      session: {
        _id: account._id,
        uid: account._id.toString(),
        userId: account._id.toString(),
        name: account.name,
        email: account.email,
        role: normalizeAccessRole(account.role),
      },
    };
  } catch {
    return null;
  }
}

async function verifyFirebaseSession(token, requireDirectoryProfile = false) {
  const verifier = requireDirectoryProfile ? verifyDirectoryFirebaseToken : verifyClientFirebaseToken;
  const decodedToken = await verifier(token);
  const uid = decodedToken.uid || decodedToken.user_id || decodedToken.sub;

  if (!requireDirectoryProfile) {
    return {
      source: "firebase",
      decodedToken,
      session: {
        uid,
        userId: uid,
        email: decodedToken.email || "",
        role: normalizeAccessRole(decodedToken.role),
      },
    };
  }

  const firebaseAccount = await getFirebaseAccount(uid);
  const profile = await getProfileByFirebaseIdentity(decodedToken);

  if (!profile) {
    const roleFromToken = normalizeAccessRole(decodedToken.role || (decodedToken.admin ? "admin" : ""));
    if (roleFromToken === "admin") {
      return {
        source: "firebase",
        decodedToken,
        firebaseAccount,
        session: {
          uid,
          userId: uid,
          email: decodedToken.email || firebaseAccount?.email || "",
          name: decodedToken.name || firebaseAccount?.displayName || "",
          role: roleFromToken,
        },
      };
    }

    const error = new Error("Access denied. Account profile not found.");
    error.status = 403;
    throw error;
  }

  if (normalizeStatus(profile, firebaseAccount) === "blocked") {
    const error = new Error("This account is blocked. Please contact support.");
    error.status = 403;
    throw error;
  }

  return {
    source: "firebase",
    decodedToken,
    firebaseAccount,
    profile,
    session: toAccountResponse(profile, firebaseAccount || decodedToken),
  };
}

const protectSession = async (req, res, next) => {
  const token = getBearerToken(req);
  if (!token) {
    return res.status(401).json({ message: "Not authorized, no token" });
  }

  try {
    try {
      const firebaseResult = await verifyFirebaseSession(token, false);
      req.authSource = firebaseResult.source;
      req.firebaseUser = firebaseResult.decodedToken;
      req.user = firebaseResult.session;
      return next();
    } catch (firebaseError) {
      const jwtResult = await verifyLegacyJwt(token);
      if (jwtResult) {
        req.authSource = jwtResult.source;
        req.legacyAccount = jwtResult.account;
        req.user = jwtResult.session;
        return next();
      }
      throw firebaseError;
    }
  } catch (error) {
    console.error("Session auth error:", error.message);
    return res.status(error.status || 401).json({ message: error.message || "Not authorized, token failed" });
  }
};

const protectTrustedSession = async (req, res, next) => {
  const token = getBearerToken(req);
  if (!token) {
    return res.status(401).json({ message: "Not authorized, no token" });
  }

  try {
    const jwtResult = await verifyLegacyJwt(token);
    if (jwtResult) {
      req.authSource = jwtResult.source;
      req.legacyAccount = jwtResult.account;
      req.user = jwtResult.session;
      return next();
    }

    const firebaseResult = await verifyFirebaseSession(token, true);
    req.authSource = firebaseResult.source;
    req.firebaseUser = firebaseResult.decodedToken;
    req.firebaseAccount = firebaseResult.firebaseAccount;
    req.userProfile = firebaseResult.profile;
    req.user = firebaseResult.session;
    return next();
  } catch (error) {
    console.error("Session auth error:", error.message);
    return res.status(error.status || 401).json({ message: error.message || "Not authorized, token failed" });
  }
};

const requirePlatformAccess = (req, res, next) => {
  if (normalizeAccessRole(req.user?.role) === "admin") {
    return next();
  }

  return res.status(403).json({ message: "Protected access only" });
};

module.exports = {
  protectSession,
  protectTrustedSession,
  requirePlatformAccess,
};

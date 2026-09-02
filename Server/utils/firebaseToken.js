/**
 * Module: Unified Utilities
 * Purpose: Provides helper functions used by backend routes, middleware, or data mapping logic.
 */
const crypto = require("crypto");
const https = require("https");
const getFirebaseApp = require("../config/firebase");

let firebaseCertCache = { expiresAt: 0, certs: null };

function base64UrlDecode(value) {
  const padded = value
    .replace(/-/g, "+")
    .replace(/_/g, "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  return Buffer.from(padded, "base64").toString("utf8");
}

function parseJwt(token) {
  const parts = String(token || "").split(".");
  if (parts.length !== 3) throw new Error("Invalid Firebase token format");

  return {
    header: JSON.parse(base64UrlDecode(parts[0])),
    payload: JSON.parse(base64UrlDecode(parts[1])),
    signedPart: `${parts[0]}.${parts[1]}`,
    signature: parts[2].replace(/-/g, "+").replace(/_/g, "/"),
  };
}

function fetchFirebaseCerts() {
  return new Promise((resolve, reject) => {
    https
      .get(
        "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com",
        (res) => {
          let data = "";
          res.on("data", (chunk) => (data += chunk));
          res.on("end", () => {
            try {
              const maxAge = /max-age=(\d+)/.exec(res.headers["cache-control"] || "")?.[1];
              firebaseCertCache = {
                expiresAt: Date.now() + Number(maxAge || 3600) * 1000,
                certs: JSON.parse(data),
              };
              resolve(firebaseCertCache.certs);
            } catch (error) {
              reject(error);
            }
          });
        }
      )
      .on("error", reject);
  });
}

async function getFirebaseCerts() {
  if (firebaseCertCache.certs && firebaseCertCache.expiresAt > Date.now()) {
    return firebaseCertCache.certs;
  }
  return fetchFirebaseCerts();
}

async function verifyFirebaseTokenWithPublicCert(idToken) {
  const parsed = parseJwt(idToken);
  const certs = await getFirebaseCerts();
  const cert = certs[parsed.header.kid];

  if (!cert) throw new Error("Firebase public certificate not found for token");

  const verifier = crypto.createVerify("RSA-SHA256");
  verifier.update(parsed.signedPart);
  verifier.end();

  const isValid = verifier.verify(cert, parsed.signature, "base64");
  if (!isValid) throw new Error("Firebase token signature is invalid");

  const payload = parsed.payload;
  const projectId = process.env.FB_PROJECT_ID || process.env.FIREBASE_PROJECT_ID || payload.aud;
  const expectedIssuer = `https://securetoken.google.com/${projectId}`;

  if (payload.aud !== projectId) throw new Error("Firebase token project/audience mismatch");
  if (payload.iss !== expectedIssuer) throw new Error("Firebase token issuer mismatch");
  if (!payload.sub) throw new Error("Firebase token subject missing");
  if (payload.exp * 1000 <= Date.now()) throw new Error("Firebase token expired");

  return {
    ...payload,
    uid: payload.user_id || payload.sub,
    email: payload.email || "",
  };
}

async function verifyFirebaseToken(idToken) {
  const firebaseApp = getFirebaseApp();

  if (firebaseApp) {
    try {
      return await firebaseApp.auth().verifyIdToken(idToken, true);
    } catch (error) {
      console.warn("Firebase Admin verify failed, trying public certificate verification:", error.message);
    }
  }

  return verifyFirebaseTokenWithPublicCert(idToken);
}

module.exports = {
  verifyFirebaseToken,
  verifyFirebaseTokenWithPublicCert,
};

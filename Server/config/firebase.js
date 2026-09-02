/**
 * Module: Config
 * Purpose: Handles the Firebase SDK setup used for token checks and account actions.
 */
const firebaseService = require("firebase-admin");

function cleanPrivateKey(value) {
  if (!value) return value;
  return value.replace(/\\n/g, "\n");
}

function parseServiceAccount() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    const parsed = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    if (parsed.private_key) parsed.private_key = cleanPrivateKey(parsed.private_key);
    return parsed;
  }

  if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
    const parsed = JSON.parse(
      Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, "base64").toString("utf8")
    );
    if (parsed.private_key) parsed.private_key = cleanPrivateKey(parsed.private_key);
    return parsed;
  }

  if (
    (process.env.FB_PROJECT_ID || process.env.FIREBASE_PROJECT_ID) &&
    (process.env.FB_CLIENT_EMAIL || process.env.FIREBASE_CLIENT_EMAIL) &&
    (process.env.FB_PRIVATE_KEY || process.env.FIREBASE_PRIVATE_KEY)
  ) {
    return {
      project_id: process.env.FB_PROJECT_ID || process.env.FIREBASE_PROJECT_ID,
      client_email: process.env.FB_CLIENT_EMAIL || process.env.FIREBASE_CLIENT_EMAIL,
      private_key: cleanPrivateKey(process.env.FB_PRIVATE_KEY || process.env.FIREBASE_PRIVATE_KEY),
    };
  }

  return null;
}

function getFirebaseApp() {
  if (firebaseService.apps.length) return firebaseService;

  const serviceAccount = parseServiceAccount();

  if (!serviceAccount) {
    return null;
  }

  firebaseService.initializeApp({
    credential: firebaseService.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id || process.env.FB_PROJECT_ID || process.env.FIREBASE_PROJECT_ID,
  });

  return firebaseService;
}

module.exports = getFirebaseApp;

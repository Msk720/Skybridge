/**
 * Module: Config
 * Purpose: Handles the single MongoDB connection used by the backend.
 */
const mongoose = require("mongoose");
const { MongoClient } = require("mongodb");

// Do not auto-create empty MongoDB collections just because a Mongoose model was loaded.
mongoose.set("autoCreate", false);
mongoose.set("autoIndex", false);

let mongooseConnectionPromise;
let nativeMongoClient;
let nativeMongoClientPromise;

function getMongoUri() {
  return process.env.MONGODB_URI || process.env.MONGO_URI;
}

function requireMongoUri() {
  const mongoUri = getMongoUri();

  if (!mongoUri) {
    throw new Error("MONGODB_URI or MONGO_URI is missing");
  }

  return mongoUri;
}

async function connectDatabase() {
  const mongoUri = requireMongoUri();

  if (mongoose.connection.readyState === 1) {
    return mongoose.connection;
  }

  if (!mongooseConnectionPromise) {
    mongooseConnectionPromise = mongoose
      .connect(mongoUri, {
        serverSelectionTimeoutMS: 30000,
      })
      .then((connection) => {
        console.log(`✅ MongoDB connected: ${connection.connection.host}`);
        return connection;
      })
      .catch((error) => {
        mongooseConnectionPromise = null;
        throw error;
      });
  }

  return mongooseConnectionPromise;
}

async function getMongoClient() {
  const mongoUri = requireMongoUri();

  if (nativeMongoClient) {
    return nativeMongoClient;
  }

  if (!nativeMongoClientPromise) {
    nativeMongoClientPromise = MongoClient
      .connect(mongoUri, {
        maxPoolSize: 10,
        serverSelectionTimeoutMS: 30000,
      })
      .then((client) => {
        console.log("✅ MongoDB native client connected");
        nativeMongoClient = client;
        return nativeMongoClient;
      })
      .catch((error) => {
        nativeMongoClientPromise = null;
        throw error;
      });
  }

  return nativeMongoClientPromise;
}

module.exports = {
  connectDatabase,
  getMongoClient,
  getMongoUri,
};

/**
 * Module: Unified Models
 * Purpose: Creates flexible Mongoose models for existing MongoDB collections without changing schemas.
 */
const mongoose = require("mongoose");

function createFlexibleModel(modelName, collectionName) {
    const schema = new mongoose.Schema(
        {},
        {
            strict: false,
            collection: collectionName,
            versionKey: false,
            autoCreate: false,
            autoIndex: false,
        }
    );

    return mongoose.models[modelName] || mongoose.model(modelName, schema);
}

module.exports = createFlexibleModel;

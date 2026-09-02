/**
 * Module: Unified Models
 * Purpose: Defines or exports MongoDB/Mongoose models used by the unified backend.
 */
const createFlexibleModel = require("./flexibleModelFactory");
module.exports = createFlexibleModel("Offer", "offers");

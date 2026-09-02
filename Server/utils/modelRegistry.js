/**
 * Module: Models
 * Purpose: Provides collection-to-model lookup for detailed and search record endpoints.
 */
const createFlexibleModel = require("../models/flexibleModelFactory");
const Offer = require("../models/Offer");
const Order = require("../models/Order");
const Payment = require("../models/Payment");
const Notification = require("../models/Notification");
const Rating = require("../models/Rating");
const StripeConnect = require("../models/StripeConnect");
const StripeEvent = require("../models/StripeEvent");

const Profile = createFlexibleModel("CrudProfile", "profiles");
const Item = createFlexibleModel("CrudItem", "items");
const Trip = createFlexibleModel("CrudTrip", "trips");
const Product = createFlexibleModel("CrudProduct", "Products");

const modelMap = {
  profiles: Profile,
  items: Item,
  trips: Trip,
  offers: Offer,
  orders: Order,
  payments: Payment,
  notifications: Notification,
  ratings: Rating,
  stripeconnect: StripeConnect,
  Products: Product,
  products: Product,
  stripeEvents: StripeEvent,
};

const searchTypeMap = {
  trips: Trip,
  shipments: Item,
  items: Item,
};

function getModelByCollection(collection) {
  return modelMap[collection] || null;
}

function getSearchModel(type) {
  return searchTypeMap[type] || Item;
}

function normalizeDoc(doc) {
  const plain = typeof doc?.toObject === "function" ? doc.toObject() : (doc || {});
  return {
    ...plain,
    id: plain._id ? plain._id.toString() : plain.id,
    _id: undefined,
  };
}

module.exports = {
  getModelByCollection,
  getSearchModel,
  normalizeDoc,
};

/**
 * Module: Config
 * Purpose: Creates the Stripe client used by payment routes.
 */
const Stripe = require("stripe");

const secret = process.env.STRIPE_SECRET;

if (!secret) {
  throw new Error("STRIPE_SECRET is missing");
}

const stripe = new Stripe(secret, {
  apiVersion: "2023-10-16",
});

module.exports = stripe;

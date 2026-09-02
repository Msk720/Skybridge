/**
 * Module: Server
 * Purpose: Main Express entry point for the complete backend.
 */
const path = require("path");
require("dotenv").config({ path: path.join(__dirname, ".env") });

const dns = require("dns");
const express = require("express");
const cors = require("cors");

const { connectDatabase, getMongoClient } = require("./config/db");
const authRoutes = require("./routes/authRoutes");
const accountRoutes = require("./routes/accountRoutes");
const messageRoutes = require("./routes/messageRoutes");
const healthRoutes = require("./routes/healthRoutes");
const profileRoutes = require("./routes/profileRoutes");
const notificationRoutes = require("./routes/notificationRoutes");
const ratingRoutes = require("./routes/ratingRoutes");
const offerRoutes = require("./routes/offerRoutes");
const entityRoutes = require("./routes/entityRoutes");
const orderRoutes = require("./routes/orderRoutes");
const disputeRoutes = require("./routes/disputeRoutes");
const paymentRoutes = require("./routes/paymentRoutes");
const autoExpireRoutes = require("./routes/autoExpireRoutes");
const recommendationRoutes = require("./routes/recommendationRoutes");
const crudRoutes = require("./routes/crud");
const recordRoutes = require("./routes/recordRoutes");
const { DISPUTE_WINDOW_MINUTES, getDisputeWindowLabel, autoReleaseDisputeWindowPayments } = require("./utils/disputePaymentUtils");

dns.setServers(["8.8.8.8", "8.8.4.4"]);
dns.setDefaultResultOrder("ipv4first");

const app = express();

app.use(cors());
app.use(
  express.json({
    limit: "10mb",
    verify: (req, res, buf) => {
      req.rawBody = buf;
    },
  })
);
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "Backend is running ✅",
    apiBase: "/api",
  });
});


const routeMounts = [
  ["/api/auth", authRoutes],
  ["/api/accounts", accountRoutes],
  ["/api/orders", orderRoutes],
  ["/api/disputes", disputeRoutes],
  ["/api/messages", messageRoutes],
  ["/api", healthRoutes],
  ["/api", profileRoutes],
  ["/api", notificationRoutes],
  ["/api", ratingRoutes],
  ["/api", offerRoutes],
  ["/api", entityRoutes],
  ["/api", paymentRoutes],
  ["/api", autoExpireRoutes],
  ["/api", recommendationRoutes],
  ["/api", crudRoutes],
  ["/api", recordRoutes],
];

for (const [basePath, routeHandler] of routeMounts) {
  app.use(basePath, routeHandler);
}

app.use((req, res) => {
  res.status(404).json({ message: "Route not found" });
});

app.use((err, req, res, next) => {
  console.error("Backend error:", err);
  res.status(err.status || 500).json({ message: err.message || "Server error" });
});

const PORT = process.env.PORT || 5000;

connectDatabase()
  .then(() => {
    app.listen(PORT, "0.0.0.0", () => {


      setInterval(async () => {
        try {
          const client = await getMongoClient();
          const db = client.db("myDatabase");
          const result = await autoReleaseDisputeWindowPayments(db);
          if (result.checked > 0) {
            console.log(`✅ Auto release checked ${result.checked} dispute-window payment(s).`);
          }
        } catch (error) {
          console.error("Auto release dispute-window payments error:", error.message);
        }
      }, 60 * 1000);
    });
  })
  .catch((error) => {
    console.error("❌ Failed to start backend:", error.message);
    process.exit(1);
  });

module.exports = app;

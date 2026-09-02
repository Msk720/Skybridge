# 🚚 SkyBridge

<p align="center">
  <img src="assets/banner/banner.png" alt="SkyBridge Banner" width="100%">
</p>

<p align="center">

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)
![Express.js](https://img.shields.io/badge/Express.js-000000?style=for-the-badge&logo=express&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB-4EA94B?style=for-the-badge&logo=mongodb&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Stripe](https://img.shields.io/badge/Stripe-635BFF?style=for-the-badge&logo=stripe&logoColor=white)

</p>

---

# 📖 Overview

SkyBridge is a full-stack logistics and shipment management platform developed as a Final Year Project (FYP). The platform connects customers, transporters, and administrators through a modern digital system that simplifies shipment booking, management, payment processing, and dispute resolution.

The project consists of a Flutter mobile application for users, a React-based admin dashboard, and a Node.js backend with MongoDB for data management.

---

# ✨ Key Features

### 👤 User Application

- User Registration & Login
- Secure Authentication
- Shipment Booking
- Shipment Tracking
- Transporter Offers
- Offer Acceptance
- Shipment History
- Stripe Payment Integration
- Cloudinary Image Upload
- Firebase Notifications
- User Profile Management

---

### 🛠 Admin Dashboard

- Dashboard Overview
- User Management
- Account Management
- Shipment Management
- Dispute Management
- Payment Monitoring
- Analytics & Reports
- Profile Management

---

### ⚙ Backend

- RESTful API
- Firebase Integration
- MongoDB Database
- Cloudinary Integration
- Stripe Payment Processing
- Secure Middleware
- Role-Based Authorization

---

# 🏗 System Architecture

```text
Flutter Mobile App
        │
        ▼
 REST API (Node.js + Express)
        │
        ▼
     MongoDB Database
        │
 ┌──────────────┬─────────────┐
 ▼              ▼             ▼
Firebase     Stripe     Cloudinary
```

---

# 💻 Tech Stack

| Category | Technology |
|----------|------------|
| Mobile App | Flutter, Dart |
| Admin Panel | React.js |
| Backend | Node.js, Express.js |
| Database | MongoDB |
| Authentication | Firebase Authentication |
| Storage | Cloudinary |
| Payments | Stripe |
| Version Control | Git & GitHub |

---

# 📂 Project Structure

```text
SkyBridge
│
├── Client
│   ├── User (Flutter)
│   └── Admin (React)
│
├── Server
│   ├── config
│   ├── middleware
│   ├── models
│   ├── routes
│   ├── utils
│   ├── package.json
│   └── server.js
│
├── README.md
└── .gitignore
```

---

# 🚀 Getting Started

## Clone Repository

```bash
git clone https://github.com/Msk720/SkyBridge.git
```

---

## Install User App

```bash
cd Client/User
flutter pub get
flutter run
```

---

## Install Admin Panel

```bash
cd Client/Admin
npm install
npm start
```

---

## Install Backend

```bash
cd Server
npm install
npm run start
```

---

# 🔐 Environment Variables

Create a `.env` file inside the `Server` directory.

Example:

```env
PORT=
MONGODB_URI=
STRIPE_SECRET_KEY=
```

---
# 📷 Screenshots

## 📱 Mobile Application

| Login | Home |
|-------|------|
| ![Login Screen](assets/screenshots/login.png) | ![Home Screen](assets/screenshots/home.png) |

| Add Item Request | Navigation Menu |
|------------------|-----------------|
| ![Add Item Request](assets/screenshots/create_item_req.png) | ![Navigation Menu](assets/screenshots/Menu_bar.png) |

| Order Dashboard | Create Trip |
|-----------------|-------------|
| ![Order Dashboard](assets/screenshots/order_dash.png) | ![Create Trip](assets/screenshots/create_trip.png) |

| Notifications | Chat |
|---------------|------|
| ![Notifications](assets/screenshots/notifications.png) | ![Chat](assets/screenshots/chat.png) |

---

## 🖥️ Admin Dashboard

| Dispute Management | Product Management |
|--------------------|--------------------|
| ![Dispute Management](assets/screenshots/admin_dispute.png) | ![Product Management](assets/screenshots/admin_product_management.png) |

---

# 🔮 Future Improvements

- Real-time shipment tracking
- In-app messaging
- Push notifications
- AI-powered shipment recommendations
- Advanced analytics dashboard
- Multi-language support
- Dark mode
- Driver mobile application

---

# 👨‍💻 Author

**Salman Khan**

Computer Science Graduate

Flutter Developer | Aspiring Software Engineer

- GitHub: https://github.com/Msk720
- LinkedIn: https://www.linkedin.com/in/salman-khan-5a8974292

---

# 📄 License

This project is developed for educational and portfolio purposes.

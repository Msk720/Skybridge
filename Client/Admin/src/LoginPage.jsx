import React, { useState } from "react";
import "./App.css";
import { adminCheck } from "./api";
import { FiMail, FiLock, FiEye, FiEyeOff } from "react-icons/fi";

import {
  signInWithEmailAndPassword,
} from "firebase/auth";

import { auth } from "./firebase";

function LoginPage({ onLoginSuccess }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [successMessage, setSuccessMessage] = useState("");

  const handleSubmit = async (e) => {
    e.preventDefault();

    setError("");
    setSuccessMessage("");
    setLoading(true);

    try {
      const credential = await signInWithEmailAndPassword(
        auth,
        email.trim(),
        password.trim()
      );

      const firebaseUser = credential.user;

      const token = await firebaseUser.getIdToken(true);

      localStorage.setItem("firebaseUid", firebaseUser.uid);
      localStorage.setItem("token", token);

      const verified = await adminCheck();
      const adminUser = verified.user;

      if (!adminUser || adminUser.role !== "admin") {
        localStorage.removeItem("firebaseUid");
        localStorage.removeItem("token");
        localStorage.removeItem("user");
        await auth.signOut();
        setError("Only administrators can access this panel.");
        return;
      }

      localStorage.setItem("user", JSON.stringify(adminUser));
      setSuccessMessage("Login successful.");

      if (onLoginSuccess) {
        onLoginSuccess(adminUser);
      }

    } catch (err) {
      localStorage.removeItem("firebaseUid");
      localStorage.removeItem("token");
      localStorage.removeItem("user");
      await auth.signOut().catch(() => {});

      const serverMessage = err.message || "Login failed";
      if (serverMessage.toLowerCase().includes("admin")) {
        setError("Only administrators can access this panel.");
      } else {
        setError(serverMessage);
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <div className="login-left">
          <p className="mini-heading">Admin Panel</p>
          <h1 className="main-heading">Admin Log In</h1>
          <p className="subtitle">
            Please log in with an admin account to manage users, products, orders, reports, disputes, and messages.
          </p>

          <form className="login-form" onSubmit={handleSubmit}>
            <label className="input-label">
              Email ID
              <div className="input-with-icon">
                <FiMail className="input-icon" />
                <input
                  type="email"
                  placeholder="Enter your email"
                  required
                  className="text-input"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                />
              </div>
            </label>

            <label className="input-label">
              Password
              <div className="input-with-icon">
                <FiLock className="input-icon" />
                <input
                  type={showPassword ? "text" : "password"}
                  placeholder="Enter your password"
                  required
                  className="text-input"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />

                {showPassword ? (
                  <FiEyeOff
                    className="eye-icon"
                    onClick={() => setShowPassword(false)}
                  />
                ) : (
                  <FiEye
                    className="eye-icon"
                    onClick={() => setShowPassword(true)}
                  />
                )}
              </div>
            </label>


            {error && <p className="auth-inline-error">{error}</p>}
            {successMessage && <div className="auth-inline-success">{successMessage}</div>}

            <button type="submit" className="submit-btn" disabled={loading}>
              {loading ? "Logging in..." : "Submit Now ↗"}
            </button>
          </form>

        </div>

        <div className="login-right"></div>
      </div>

      {successMessage && (
        <div className="auth-floating-alert success">{successMessage}</div>
      )}
    </div>
  );
}

export default LoginPage;

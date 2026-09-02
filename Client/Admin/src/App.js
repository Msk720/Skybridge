// Admin-only React app
import { useEffect, useState } from "react";
import "./App.css";

import LoginPage from "./LoginPage";
import AdminDashboard from "./AdminDashboard";
import { getCurrentUser } from "./api";

import {
  BrowserRouter as Router,
  Routes,
  Route,
  Navigate,
  useNavigate,
} from "react-router-dom";

function AdminLoginWrapper({ onLoginSuccess }) {
  const navigate = useNavigate();

  const handleSuccess = (user) => {
    if (user?.role !== "admin") {
      localStorage.removeItem("firebaseUid");
      localStorage.removeItem("token");
      localStorage.removeItem("user");
      return;
    }

    onLoginSuccess(user);
    navigate("/admin", { replace: true });
  };

  return <LoginPage onLoginSuccess={handleSuccess} />;
}

function ProtectedAdminRoute({ currentUser, onLogout }) {
  if (!currentUser) {
    return <Navigate to="/login" replace />;
  }

  if (currentUser.role !== "admin") {
    return <Navigate to="/login" replace />;
  }

  return <AdminDashboard onLogout={onLogout} />;
}

function AppContent({ currentUser, handleLoginSuccess, handleLogout }) {
  return (
    <Routes>
      <Route
        path="/"
        element={<Navigate to={currentUser?.role === "admin" ? "/admin" : "/login"} replace />}
      />

      <Route
        path="/login"
        element={
          currentUser?.role === "admin" ? (
            <Navigate to="/admin" replace />
          ) : (
            <AdminLoginWrapper onLoginSuccess={handleLoginSuccess} />
          )
        }
      />

      <Route
        path="/admin"
        element={<ProtectedAdminRoute currentUser={currentUser} onLogout={handleLogout} />}
      />

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

function App() {
  const [currentUser, setCurrentUser] = useState(null);

  useEffect(() => {
    const verifySavedAdmin = async () => {
      const savedUser = localStorage.getItem("user");
      const token = localStorage.getItem("token");

      if (!savedUser || !token) return;

      try {
        const parsedUser = JSON.parse(savedUser);
        if (parsedUser?.role !== "admin") {
          localStorage.removeItem("firebaseUid");
          localStorage.removeItem("token");
          localStorage.removeItem("user");
          return;
        }

        const verified = await getCurrentUser();
        if (verified?.user?.role === "admin") {
          localStorage.setItem("user", JSON.stringify(verified.user));
          setCurrentUser(verified.user);
          return;
        }
      } catch {
        // Saved session is not a valid admin session anymore.
      }

      localStorage.removeItem("firebaseUid");
      localStorage.removeItem("token");
      localStorage.removeItem("user");
      setCurrentUser(null);
    };

    verifySavedAdmin();
  }, []);

  const handleLoginSuccess = (user) => {
    setCurrentUser(user);
  };

  const handleLogout = () => {
    localStorage.removeItem("firebaseUid");
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    setCurrentUser(null);
  };

  return (
    <Router>
      <AppContent
        currentUser={currentUser}
        handleLoginSuccess={handleLoginSuccess}
        handleLogout={handleLogout}
      />
    </Router>
  );
}

export default App;

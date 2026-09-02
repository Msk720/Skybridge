import React, { useEffect, useMemo, useRef, useState } from "react";
import {
  FaBars,
  FaBell,
  FaBoxOpen,
  FaChartLine,
  FaCheck,
  FaChevronRight,
  FaCircle,
  FaEye,
  FaGear,
  FaPenToSquare,
  FaPlus,
  FaTrash,
  FaUsers,
  FaXmark,
  FaCrown,
  FaTriangleExclamation,
  FaUserCheck,
  FaUserSlash,
  FaMessage,
  FaUser
} from "react-icons/fa6";

import {
  getAllUsers,
  updateUserStatus,
  deleteUser,
  getAllProducts,
  createProduct,
  updateProduct,
  deleteProduct,
  getAllDisputes,
  updateDisputeStatus as updateDisputeStatusApi,
  handleDisputePayment as handleDisputePaymentApi,
  getAdminMessages,
  replyToMessage,
  startAdminChat,
} from "./api";
import { PRODUCT_URL_PATTERN, PRODUCT_URL_TITLE, validateProductForm } from "./productValidator";
import "./AdminDashboard.css";

const INITIAL_PRODUCT_FORM = {
  name: "",
  storeName: "",
  category: "",
  price: "",
  weight: "",
  status: "active",
  image: "",
  storeLink: "",
};

const TAB_ITEMS = [
  { key: "overview", label: "Dashboard", icon: <FaChartLine /> },
  { key: "products", label: "Manage Products", icon: <FaBoxOpen /> },
  { key: "users", label: "Manage Users", icon: <FaUsers /> },
  { key: "disputes", label: "Manage Disputes", icon: <FaTriangleExclamation /> },
  { key: "messages", label: "User Messages", icon: <FaMessage /> },
];

const PRODUCT_CATEGORY_OPTIONS = [
  { value: "electronics", label: "Electronics" },
  { value: "cosmetics", label: "Cosmetics" },
  { value: "clothing", label: "Clothing" },
  { value: "bags", label: "Bags" },
  { value: "shoes", label: "Shoes" },
  { value: "accessories", label: "Accessories" },
  { value: "medicine", label: "Medicine" },
  { value: "home", label: "Home" },
  { value: "sports", label: "Sports" },
  { value: "books", label: "Books" },
  { value: "toys", label: "Toys" },
  { value: "fragrance", label: "Fragrance" },
  { value: "other", label: "Other" },
];

const PRODUCT_FALLBACK_IMAGE =
  "https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=1200&q=80";

const STRIPE_SANDBOX_PAYMENTS_URL = "https://dashboard.stripe.com/test/payments";

const CLOUDINARY_CLOUD_NAME = "daajwglxs";
const CLOUDINARY_UPLOAD_PRESET = "SkyBridge";

async function uploadAdminChatImage(file) {
  const formData = new FormData();
  formData.append("upload_preset", CLOUDINARY_UPLOAD_PRESET);
  formData.append("file", file);

  const response = await fetch(`https://api.cloudinary.com/v1_1/${CLOUDINARY_CLOUD_NAME}/auto/upload`, {
    method: "POST",
    body: formData,
  });
  const data = await response.json();
  if (!response.ok || !data.secure_url) {
    throw new Error(data.error?.message || "Image upload failed");
  }
  return data.secure_url;
}

function formatMoney(value) {
  return `$${Number(value || 0).toLocaleString()}`;
}

function productCategoryLabel(value) {
  const normalized = String(value || "").toLowerCase();
  return PRODUCT_CATEGORY_OPTIONS.find((item) => item.value === normalized)?.label || value || "—";
}

function formatDate(value) {
  if (!value) return "—";
  return new Date(value).toLocaleDateString();
}

function formatDateTime(value) {
  if (!value) return "—";

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);

  return date.toLocaleString([], {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function pickText(...values) {
  for (const value of values) {
    if (value === undefined || value === null) continue;
    const text = String(value).trim();
    if (text) return text;
  }

  return "";
}

function titleCase(value) {
  return String(value || "")
    .replace(/[_-]+/g, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(" ");
}

function normalizeDisputeStatus(value) {
  const status = String(value || "under_review").toLowerCase().replace(/[\s-]+/g, "_");

  if (["pending", "open", "review", "in_review", "investigating", "in_progress", "inprogress"].includes(status)) return "under_review";
  if (["solved", "closed"].includes(status)) return "resolved";
  if (["declined"].includes(status)) return "rejected";
  if (["canceled"].includes(status)) return "cancelled";

  return status || "under_review";
}

function formatDisputeStatus(value) {
  const status = normalizeDisputeStatus(value);
  const labels = {
    under_review: "Pending",
    resolved: "Resolved",
    rejected: "Rejected",
    cancelled: "Cancelled",
    closed: "Closed",
  };

  return labels[status] || titleCase(status);
}

function formatRoleLabel(value) {
  const role = String(value || "buyer").toLowerCase().trim();

  if (["traveler", "traveller"].includes(role)) return "Traveler";
  if (["buyer", "customer", "user"].includes(role)) return "Buyer";

  return titleCase(role) || "Buyer";
}

function getInitials(name) {
  const parts = String(name || "User")
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  if (!parts.length) return "U";

  return parts
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join("");
}

function getDisputeFilerInfo(dispute = {}) {
  const rawRole = pickText(
    dispute.filedByRole,
    dispute.viewerRole,
    dispute.userRole,
    dispute.currentRole,
    dispute.filedBy?.role,
    dispute.user?.role,
    dispute.role
  );
  const role = formatRoleLabel(rawRole || "buyer");
  const roleValue = role.toLowerCase();
  const isTraveler = roleValue === "traveler";

  const name = pickText(
    dispute.filerName,
    dispute.filedByName,
    dispute.filedBy?.name,
    dispute.userName,
    dispute.user?.name,
    isTraveler ? dispute.travelerName : dispute.buyerName,
    isTraveler ? dispute.traveler?.name : dispute.buyer?.name,
    isTraveler ? dispute.order?.traveler?.name : dispute.order?.buyer?.name,
    dispute.buyerName,
    dispute.travelerName,
    "User"
  );

  const email = pickText(
    dispute.filerEmail,
    dispute.filedByEmail,
    dispute.filedBy?.email,
    dispute.userEmail,
    dispute.user?.email,
    isTraveler ? dispute.travelerEmail : dispute.buyerEmail,
    isTraveler ? dispute.traveler?.email : dispute.buyer?.email,
    isTraveler ? dispute.order?.traveler?.email : dispute.order?.buyer?.email,
    dispute.buyerEmail,
    dispute.travelerEmail,
    "—"
  );

  const id = pickText(
    dispute.filerId,
    dispute.filedById,
    dispute.filedBy?._id,
    dispute.filedBy?.id,
    dispute.userId,
    dispute.user?._id,
    dispute.user?.id,
    isTraveler ? dispute.travelerUid : dispute.buyerUid,
    isTraveler ? dispute.traveler?._id : dispute.buyer?._id,
    isTraveler ? dispute.order?.traveler?._id : dispute.order?.buyer?._id,
    dispute._id,
    "—"
  );

  const against = formatRoleLabel(
    pickText(dispute.againstRole, isTraveler ? "buyer" : "traveler")
  );
  const againstRoleValue = against.toLowerCase();
  const againstIsTraveler = againstRoleValue === "traveler";

  const againstName = pickText(
    dispute.againstName,
    dispute.againstUserName,
    dispute.againstUser?.name,
    dispute.against?.name,
    againstIsTraveler ? dispute.travelerName : dispute.buyerName,
    againstIsTraveler ? dispute.traveler?.name : dispute.buyer?.name,
    againstIsTraveler ? dispute.order?.traveler?.name : dispute.order?.buyer?.name,
    isTraveler ? dispute.buyerName : dispute.travelerName,
    isTraveler ? dispute.buyer?.name : dispute.traveler?.name,
    "—"
  );

  const againstEmail = pickText(
    dispute.againstEmail,
    dispute.againstUserEmail,
    dispute.againstUser?.email,
    dispute.against?.email,
    againstIsTraveler ? dispute.travelerEmail : dispute.buyerEmail,
    againstIsTraveler ? dispute.traveler?.email : dispute.buyer?.email,
    againstIsTraveler ? dispute.order?.traveler?.email : dispute.order?.buyer?.email,
    isTraveler ? dispute.buyerEmail : dispute.travelerEmail,
    isTraveler ? dispute.buyer?.email : dispute.traveler?.email,
    "—"
  );

  const againstId = pickText(
    dispute.againstId,
    dispute.againstUserId,
    dispute.againstUser?._id,
    dispute.againstUser?.id,
    dispute.against?._id,
    dispute.against?.id,
    againstIsTraveler ? dispute.travelerUid : dispute.buyerUid,
    againstIsTraveler ? dispute.traveler?._id : dispute.buyer?._id,
    againstIsTraveler ? dispute.traveler?.id : dispute.buyer?.id,
    againstIsTraveler ? dispute.order?.traveler?._id : dispute.order?.buyer?._id,
    againstIsTraveler ? dispute.order?.traveler?.id : dispute.order?.buyer?.id,
    isTraveler ? dispute.buyerUid : dispute.travelerUid,
    isTraveler ? dispute.buyer?._id : dispute.traveler?._id,
    isTraveler ? dispute.buyer?.id : dispute.traveler?.id,
    "—"
  );

  return {
    name,
    email,
    id,
    role,
    roleValue,
    against,
    againstName,
    againstEmail,
    againstId,
    initials: getInitials(name),
  };
}

function getDisputeOrderNumber(dispute = {}) {
  const orderId = dispute.orderId;

  if (orderId && typeof orderId === "object") {
    return pickText(orderId.id, orderId._id, orderId.orderNumber, "N/A");
  }

  return pickText(orderId, dispute.order?._id, dispute.order?.id, dispute.orderNumber, "N/A");
}

function shortId(value, length = 8) {
  const clean = String(value || "").trim();
  if (!clean || clean === "N/A") return "N/A";
  if (clean.length <= length) return clean.toUpperCase();
  return clean.slice(-length).toUpperCase();
}

function getDisputeIssueInfo(dispute = {}) {
  return {
    nature: pickText(dispute.natureOfDispute, dispute.reason, dispute.title, dispute.type, "Dispute"),
    item: pickText(dispute.itemDescription, dispute.itemName, dispute.productName, dispute.name, "—"),
    details: pickText(dispute.extraDetails, dispute.description, dispute.message, dispute.details, "—"),
    evidence: pickText(
      dispute.documentURL,
      dispute.documentUrl,
      dispute.evidenceURL,
      dispute.evidenceUrl,
      dispute.evidenceImage,
      dispute.evidenceImageUrl,
      dispute.attachmentUrl,
      dispute.attachmentURL,
      dispute.proofUrl,
      dispute.proofImage
    ),
  };
}

function getDisputeItemImage(dispute = {}) {
  return pickText(
    dispute.itemImage,
    dispute.itemImageUrl,
    dispute.productImage,
    dispute.productImageUrl,
    dispute.product?.image,
    dispute.product?.imageUrl,
    dispute.product?.photo,
    dispute.order?.itemImage,
    dispute.order?.product?.image,
    dispute.order?.product?.imageUrl,
    dispute.order?.productImage,
    dispute.orderId?.itemImage,
    dispute.orderId?.product?.image,
    dispute.orderId?.product?.imageUrl,
    dispute.orderId?.productImage,
    dispute.image,
    dispute.imageUrl
  );
}

function getDisputeProductId(dispute = {}) {
  return pickText(
    dispute.productId,
    dispute.itemId,
    dispute.item?._id,
    dispute.item?.id,
    dispute.product?._id,
    dispute.product?.id,
    dispute.order?.itemId,
    dispute.order?.productId,
    dispute.order?.item?._id,
    dispute.order?.item?.id,
    dispute.order?.product?._id,
    dispute.order?.product?.id,
    dispute.orderId?.itemId,
    dispute.orderId?.productId,
    "—"
  );
}

function moneyText(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return "—";
  return `$${numeric.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}


function getDisputeMoneyInfo(dispute = {}) {
  const totalCostPaid = pickText(
    dispute.paymentAmount,
    dispute.payment?.paymentAmount,
    dispute.order?.payment?.paymentAmount,
    dispute.totalPaid,
    dispute.totalCostPaid,
    dispute.totalPrice,
    dispute.totalAmount,
    dispute.order?.totalPaid,
    dispute.order?.totalCostPaid,
    dispute.order?.totalPrice,
    dispute.order?.totalAmount
  );

  const reward = pickText(
    dispute.reward,
    dispute.travelerReward,
    dispute.offeredReward,
    dispute.order?.reward,
    dispute.order?.travelerReward,
    dispute.order?.offeredReward
  );

  return {
    totalCostPaid: moneyText(totalCostPaid),
    reward: moneyText(reward),
  };
}


function StatusBadge({ value, type = "order" }) {
  const normalized = String(value || "")
    .toLowerCase()
    .replace(/[\s-]+/g, "_");
  const displayValue = String(value || "")
    .replace(/_/g, " ")
    .trim();

  return <span className={`admin-status-badge ${type} ${normalized}`}>{displayValue}</span>;
}

function KPI({ icon, label, value, hint, accent = "orange" }) {
  return (
    <div className={`admin-kpi-card ${accent}`}>
      <div className="admin-kpi-icon">{icon}</div>
      <div>
        <p>{label}</p>
        <h3>{value}</h3>
        <span>{hint}</span>
      </div>
    </div>
  );
}

function SnapshotCard({ title, description, buttonText, onButtonClick, stats }) {
  return (
    <div className="admin-panel-card admin-snapshot-card">
      <div className="admin-panel-head admin-snapshot-head">
        <div className="admin-snapshot-title">
          <h3>{title}</h3>
          <p>{description}</p>
        </div>
        <button className="admin-link-btn snapshot-action-btn" onClick={onButtonClick}>
          {buttonText}
        </button>
      </div>
      <div className="admin-mini-table status-cards product-snapshot-cards admin-snapshot-stats">
        {stats.map(({ label, value }) => (
          <div key={label} className="admin-mini-row stat-card admin-snapshot-stat-card">
            <div>
              <strong>{value}</strong>
              <span>{label}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function AdminDashboard({ onLogout }) {
  const [activeTab, setActiveTab] = useState("overview");
  const [users, setUsers] = useState([]);
  const [products, setProducts] = useState([]);
  const [userMessages, setUserMessages] = useState([]);
  const [replyDrafts, setReplyDrafts] = useState({});
  const [replyImages, setReplyImages] = useState({});
  const [replyTargets, setReplyTargets] = useState({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [successMessage, setSuccessMessage] = useState("");
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [confirmBox, setConfirmBox] = useState({ open: false, type: "", id: null, title: "", message: "" });
  const [confirmProcessing, setConfirmProcessing] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showSettings, setShowSettings] = useState(false);
  const [selectedThreadKey, setSelectedThreadKey] = useState("");
  const [selectedDisputeDetail, setSelectedDisputeDetail] = useState(null);
  const [selectedPaymentDispute, setSelectedPaymentDispute] = useState(null);
  const [showDisputeEvidencePreview, setShowDisputeEvidencePreview] = useState(false);
  const adminTopbarActionsRef = useRef(null);

  const [productSearch, setProductSearch] = useState("");
  const [userSearch, setUserSearch] = useState("");
  const [disputeSearch, setDisputeSearch] = useState("");
  const [disputeFilter, setDisputeFilter] = useState("all");
  const [disputes, setDisputes] = useState([]);

  const [isProductModalOpen, setIsProductModalOpen] = useState(false);
  const [productModalMode, setProductModalMode] = useState("add");
  const [editingProductId, setEditingProductId] = useState(null);
  const [productForm, setProductForm] = useState(INITIAL_PRODUCT_FORM);

  const currentAdmin = useMemo(() => {
    try {
      return JSON.parse(localStorage.getItem("user") || "null");
    } catch {
      return null;
    }
  }, []);

  useEffect(() => {
    loadAdminData();
  }, []);

  useEffect(() => {
    const handleAdminOutsideClick = (event) => {
      if (
        adminTopbarActionsRef.current &&
        !adminTopbarActionsRef.current.contains(event.target)
      ) {
        setShowNotifications(false);
        setShowSettings(false);
      }
    };

    document.addEventListener("mousedown", handleAdminOutsideClick);
    return () => document.removeEventListener("mousedown", handleAdminOutsideClick);
  }, []);

  useEffect(() => {
    if (!successMessage) return undefined;
    const timer = setTimeout(() => setSuccessMessage(""), 2600);
    return () => clearTimeout(timer);
  }, [successMessage]);

  useEffect(() => {
    setShowDisputeEvidencePreview(false);

    if (!selectedDisputeDetail) return undefined;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [selectedDisputeDetail]);

  const loadAdminData = async () => {
    try {
      setLoading(true);
      setError("");
      const [usersRes, productsRes, disputesRes, messagesRes] = await Promise.all([
        getAllUsers(),
        getAllProducts(),
        getAllDisputes(),
        getAdminMessages(),
      ]);

      const disputeList = Array.isArray(disputesRes)
        ? disputesRes
        : disputesRes.disputes || disputesRes.data || [];

      setUsers(usersRes.users || []);
      setProducts(productsRes.products || []);
      setDisputes(disputeList);
      setUserMessages(Array.isArray(messagesRes) ? messagesRes : []);
    } catch (err) {
      setError(err.message || "Failed to load admin data");
    } finally {
      setLoading(false);
    }
  };

  const filedDisputesCount = useMemo(
    () => (Array.isArray(disputes) ? disputes.length : 0),
    [disputes]
  );

  const activeProductsCount = useMemo(
    () => products.filter((product) => (product.status || "active") === "active").length,
    [products]
  );

  const inactiveProductsCount = useMemo(
    () => products.filter((product) => (product.status || "active") === "inactive").length,
    [products]
  );


  const adminUsersCount = useMemo(
    () => users.filter((user) => user.role === "admin").length,
    [users]
  );

  const inProgressDisputesCount = useMemo(
    () => (Array.isArray(disputes) ? disputes : []).filter((dispute) => normalizeDisputeStatus(dispute.status) === "under_review").length,
    [disputes]
  );

  const chatThreads = useMemo(() => {
    const grouped = new Map();

    userMessages.forEach((item) => {
      const clean = (value) => String(value || "").trim();
      const firstUsefulKey = [
        item.email,
        item.userId,
        item.user?._id,
        item.user?.id,
        item.senderId,
        item.receiverId,
        item.name,
        item._id,
      ]
        .map(clean)
        .find((value) => value && !["no email", "not available", "admin"].includes(value.toLowerCase()));

      const key = (firstUsefulKey || "unknown-user").toLowerCase();
      if (!grouped.has(key)) {
        grouped.set(key, {
          key,
          name: item.name || "User",
          email: item.email || "No email",
          userId: item.userId || item.user?._id || item.user?.id || item.receiverId || "",
          messages: [],
          hasNew: false,
          lastDate: item.createdAt || item.updatedAt || "",
        });
      }

      const thread = grouped.get(key);
      thread.messages.push(item);
      thread.hasNew = thread.hasNew || (item.status || "new") === "new";
      if ((item.createdAt || item.updatedAt || "") > thread.lastDate) {
        thread.lastDate = item.createdAt || item.updatedAt || "";
      }
    });

    return Array.from(grouped.values())
      .map((thread) => ({
        ...thread,
        messages: thread.messages.sort((a, b) => new Date(a.createdAt || 0) - new Date(b.createdAt || 0)),
      }))
      .sort((a, b) => new Date(b.lastDate || 0) - new Date(a.lastDate || 0));
  }, [userMessages]);

  const unreadMessagesCount = useMemo(
    () => chatThreads.filter((thread) => thread.hasNew).length,
    [chatThreads]
  );

  const totalChatsCount = useMemo(
    () => chatThreads.length,
    [chatThreads]
  );

  useEffect(() => {
    if (!chatThreads.length) {
      setSelectedThreadKey("");
      return;
    }
    if (!selectedThreadKey || !chatThreads.some((thread) => thread.key === selectedThreadKey)) {
      setSelectedThreadKey(chatThreads[0].key);
    }
  }, [chatThreads, selectedThreadKey]);

  const notificationItems = useMemo(() => {
    const items = [];
    if (inProgressDisputesCount > 0) items.push(`${inProgressDisputesCount} dispute case${inProgressDisputesCount > 1 ? "s" : ""} in progress`);
    if (unreadMessagesCount > 0) items.push(`${unreadMessagesCount} user${unreadMessagesCount > 1 ? "s" : ""} SMS waiting for reply`);
    if (!items.length) items.push("Everything is up to date");
    return items;
  }, [inProgressDisputesCount, unreadMessagesCount]);

  const filteredProducts = useMemo(() => {
    const query = productSearch.trim().toLowerCase();
    if (!query) return products;
    return products.filter(
      (product) =>
        product.name?.toLowerCase().includes(query) ||
        product.category?.toLowerCase().includes(query) ||
        product.storeName?.toLowerCase().includes(query) ||
        product.status?.toLowerCase().includes(query)
    );
  }, [products, productSearch]);

  const filteredUsers = useMemo(() => {
    const query = userSearch.trim().toLowerCase();
    if (!query) return users;
    return users.filter(
      (user) =>
        user.name?.toLowerCase().includes(query) ||
        user.email?.toLowerCase().includes(query) ||
        user.role?.toLowerCase().includes(query)
    );
  }, [users, userSearch]);

  const filteredDisputes = useMemo(() => {
    const query = disputeSearch.trim().toLowerCase();
    const list = Array.isArray(disputes) ? disputes : [];

    return list.filter((dispute) => {
      const status = normalizeDisputeStatus(dispute.status);
      const matchesStatus = disputeFilter === "all" || status === disputeFilter;
      const filer = getDisputeFilerInfo(dispute);
      const orderNumber = getDisputeOrderNumber(dispute);
      const issue = getDisputeIssueInfo(dispute);

      const searchableText = [
        dispute._id,
        dispute.id,
        orderNumber,
        filer.name,
        filer.email,
        issue.nature,
        issue.item,
        issue.details,
        status,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();

      return matchesStatus && (!query || searchableText.includes(query));
    });
  }, [disputes, disputeSearch, disputeFilter]);

  const disputeStatusSummary = useMemo(() => {
    const counts = { Pending: 0, Resolved: 0, Rejected: 0 };
    const list = Array.isArray(disputes) ? disputes : [];

    list.forEach((dispute) => {
      const status = normalizeDisputeStatus(dispute.status);
      if (["resolved", "cancelled"].includes(status)) counts.Resolved += 1;
      else if (status === "rejected") counts.Rejected += 1;
      else counts.Pending += 1;
    });

    return [
      { label: "Pending", value: counts.Pending },
      { label: "Resolved", value: counts.Resolved },
      { label: "Rejected", value: counts.Rejected },
    ];
  }, [disputes]);

  const askDeleteUser = (id) => {
    setConfirmBox({
      open: true,
      type: "deleteUser",
      id,
      title: "Delete this user?",
      message: "This account will be removed from the system. This action cannot be undone.",
    });
  };

  const openAddProductModal = () => {
    setProductModalMode("add");
    setEditingProductId(null);
    setProductForm(INITIAL_PRODUCT_FORM);
    setIsProductModalOpen(true);
  };

  const openEditProductModal = (product) => {
    setProductModalMode("edit");
    setEditingProductId(product._id);
    setProductForm({
      name: product.name || "",
      storeName: product.storeName || "",
      category: product.category || "",
      price: product.price || "",
      weight: product.weight || "",
      status: product.status || "active",
      image: product.image || "",
      storeLink: product.storeLink || "",
    });
    setIsProductModalOpen(true);
  };

  const handleProductInputChange = (e) => {
    const { name, value } = e.target;
    setProductForm((prev) => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleProductSubmit = async (e) => {
    e.preventDefault();
    setError("");

    const validation = validateProductForm(productForm);

    if (validation.error) {
      setError(validation.error);
      return;
    }

    const payload = validation.payload;

    try {
      setLoading(true);
      if (productModalMode === "add") {
        const createdRes = await createProduct(payload);
        const createdProduct = createdRes.product || createdRes;
        setProducts((prev) => [createdProduct, ...prev]);
        setSuccessMessage("Product created successfully.");
      } else {
        const updatedRes = await updateProduct(editingProductId, payload);
        const updatedProduct = updatedRes.product || updatedRes;
        setProducts((prev) => prev.map((product) => (product._id === editingProductId ? updatedProduct : product)));
        setSuccessMessage("Product updated successfully.");
      }
      setIsProductModalOpen(false);
    } catch (err) {
      setError(err.message || "Could not save product");
    } finally {
      setLoading(false);
    }
  };

  const askDeleteProduct = (id) => {
    setConfirmBox({
      open: true,
      type: "deleteProduct",
      id,
      title: "Delete this product?",
      message: "The product will be removed from the SkyBridge Products collection and admin records.",
    });
  };


  const updateDisputeAfterPayment = (disputeId, updatedDispute) => {
    setDisputes((prev) =>
      prev.map((dispute) =>
        String(dispute._id || dispute.id) === String(disputeId)
          ? { ...dispute, ...updatedDispute }
          : dispute
      )
    );
    setSelectedDisputeDetail((prev) =>
      prev && String(prev._id || prev.id) === String(disputeId)
        ? { ...prev, ...updatedDispute }
        : prev
    );
    setSelectedPaymentDispute((prev) =>
      prev && String(prev._id || prev.id) === String(disputeId)
        ? { ...prev, ...updatedDispute }
        : prev
    );
  };

  const executePaymentAction = async (dispute, action) => {
    const disputeId = dispute?._id || dispute?.id;
    if (!disputeId) {
      setError("Dispute ID not found.");
      return;
    }

    const updatedRes = await handleDisputePaymentApi(disputeId, { paymentDecision: action });
    const updatedDispute = updatedRes.dispute || updatedRes;

    // Frontend safety fallback: backend is source of truth, but if an older server
    // returns only a success message after Stripe action, still update the table
    // status immediately so Handle Payment becomes disabled.
    const filerRole = getDisputeFilerInfo(dispute).role.toLowerCase();
    const fallbackStatus = action === "full_refund"
      ? (filerRole.includes("traveler") ? "rejected" : "resolved")
      : (filerRole.includes("traveler") ? "resolved" : "rejected");

    updateDisputeAfterPayment(disputeId, {
      ...updatedDispute,
      status: normalizeDisputeStatus(updatedDispute.status || fallbackStatus),
      paymentDecision: action,
    });
    setSelectedPaymentDispute(null);
    setSuccessMessage("Dispute payment processed in Stripe successfully.");
  };

  const executeManualPartialRefundStatus = async (dispute) => {
    const disputeId = dispute?._id || dispute?.id;
    if (!disputeId) {
      setError("Dispute ID not found.");
      return;
    }

    const updatedRes = await updateDisputeStatusApi(disputeId, {
      status: "resolved",
      manualPartialRefundConfirmed: true,
      adminNote: "Partial refund completed manually in Stripe Sandbox.",
    });
    const updatedDispute = updatedRes.dispute || updatedRes;
    updateDisputeAfterPayment(disputeId, updatedDispute);
    setSelectedPaymentDispute(null);
    setSuccessMessage("Manual partial refund marked as resolved.");
  };

  const handleManualPartialRefundStatus = (dispute) => {
    const disputeId = dispute?._id || dispute?.id;
    if (!disputeId) {
      setError("Dispute ID not found.");
      return;
    }

    const status = normalizeDisputeStatus(dispute.status);
    if (["resolved", "rejected", "cancelled", "closed"].includes(status)) {
      setError("Payment has already been handled for this dispute.");
      return;
    }

    setConfirmBox({
      open: true,
      type: "manualPartialRefund",
      id: disputeId,
      dispute,
      title: "Manual partial refund done?",
      message: "Have you completed the partial refund manually in Stripe Sandbox? If yes, the dispute status will be updated to Resolved without running another Stripe action.",
    });
  };

  const executeRejectDispute = async (dispute) => {
    const disputeId = dispute?._id || dispute?.id;
    if (!disputeId) {
      setError("Dispute ID not found.");
      return;
    }

    const updatedRes = await updateDisputeStatusApi(disputeId, {
      status: "rejected",
      adminNote: "Dispute rejected by admin.",
    });
    const updatedDispute = updatedRes.dispute || updatedRes;
    updateDisputeAfterPayment(disputeId, {
      ...updatedDispute,
      status: normalizeDisputeStatus(updatedDispute.status || "rejected"),
    });
    setSuccessMessage("Dispute rejected successfully.");
  };

  const handleRejectDispute = async (dispute) => {
    const disputeId = dispute?._id || dispute?.id;
    if (!disputeId) {
      setError("Dispute ID not found.");
      return;
    }

    const status = normalizeDisputeStatus(dispute.status);
    if (["resolved", "rejected", "cancelled", "closed"].includes(status)) {
      setError("This dispute is already closed.");
      return;
    }

    try {
      setLoading(true);
      await executeRejectDispute(dispute);
    } catch (err) {
      setError(err.message || "Could not reject dispute");
    } finally {
      setLoading(false);
    }
  };

  const handlePaymentAction = (dispute, action) => {
    const disputeId = dispute?._id || dispute?.id;
    if (!disputeId) {
      setError("Dispute ID not found.");
      return;
    }

    const status = normalizeDisputeStatus(dispute.status);
    if (["resolved", "rejected", "cancelled", "closed"].includes(status)) {
      setError("Payment has already been handled for this dispute.");
      return;
    }

    const labels = {
      release_to_traveler: "Release payment to traveler",
      full_refund: "Refund full payment to buyer",
    };

    setConfirmBox({
      open: true,
      type: "disputePayment",
      id: disputeId,
      dispute,
      action,
      title: "Confirm dispute payment?",
      message: `${labels[action] || "Process payment"}. This will run a real Stripe action and then update the dispute status.`,
    });
  };

  const handleOpenDisputeChat = async (dispute) => {
    const filer = getDisputeFilerInfo(dispute);
    const possibleKeys = [
      filer.email,
      filer.name,
      filer.id,
      dispute.userId,
      dispute.user?.id,
      dispute.user?._id,
      dispute.filedBy?.id,
      dispute.filedBy?._id,
      dispute.filedBy?.email,
      dispute.filedById,
    ]
      .filter(Boolean)
      .map((item) => String(item).trim().toLowerCase());

    const findThread = () => chatThreads.find((item) => {
      const threadKeys = [item.key, item.email, item.name, item.userId]
        .filter(Boolean)
        .map((value) => String(value).trim().toLowerCase());

      return threadKeys.some((key) => possibleKeys.includes(key));
    });

    const thread = findThread();

    setActiveTab("messages");

    if (thread) {
      setSelectedThreadKey(thread.key);
      return;
    }

    try {
      const created = await startAdminChat({
        userId: filer.id || dispute.userId || dispute.user?.id || dispute.filedBy?.id || "",
        name: filer.name || "User",
        email: filer.email || "",
        message: "Admin opened chat from dispute case.",
        source: "dispute",
        disputeId: dispute._id || dispute.id,
      });

      await loadAdminData();

      const newKey = String(
        created?.email ||
        created?.userId ||
        created?.receiverId ||
        filer.email ||
        filer.id ||
        filer.name ||
        ""
      ).trim().toLowerCase();

      setSelectedThreadKey(newKey);
      setSuccessMessage(`Message started with ${filer.name}.`);
    } catch (err) {
      setError(err.message || `Could not start chat with ${filer.name}.`);
    }
  };


  const handleOpenAgainstUserChat = async (dispute) => {
    const filer = getDisputeFilerInfo(dispute);

    const possibleKeys = [
      filer.againstEmail,
      filer.againstName,
      filer.againstId,
      dispute.againstUser?.email,
      dispute.againstUser?.name,
      dispute.againstUser?.id,
      dispute.againstUser?._id,
      dispute.againstEmail,
      dispute.againstName,
      dispute.againstId,
    ]
      .filter(Boolean)
      .map((v) => String(v).trim().toLowerCase());

    const thread = chatThreads.find((item) => {
      const threadKeys = [item.key, item.email, item.name]
        .filter(Boolean)
        .map((v) => String(v).trim().toLowerCase());

      return threadKeys.some((k) => possibleKeys.includes(k));
    });

    setSelectedDisputeDetail(null);
    setActiveTab("messages");

    if (thread) {
      setSelectedThreadKey(thread.key);
      return;
    }

    try {
      const created = await startAdminChat({
        userId: filer.againstId,
        name: filer.againstName,
        email: filer.againstEmail,
        message: "Admin opened chat from dispute case.",
        source: "dispute",
        disputeId: dispute._id || dispute.id,
      });

      await loadAdminData();

      const newKey = String(
        created?.email ||
        created?.userId ||
        created?.receiverId ||
        filer.againstEmail ||
        filer.againstId ||
        filer.againstName ||
        ""
      )
        .trim()
        .toLowerCase();

      setSelectedThreadKey(newKey);
      setSuccessMessage(`Message started with ${filer.againstName}.`);
    } catch (err) {
      setError(err.message || `Could not start chat with ${filer.againstName}.`);
    }
  };
  const handleAdminReply = async (threadKey) => {
    const thread = chatThreads.find((item) => item.key === threadKey);
    const selectedId = replyTargets[threadKey];
    const targetMessage =
      thread?.messages.find((message) => message._id === selectedId) ||
      [...(thread?.messages || [])].reverse().find((message) => (message.status || "new") === "new") ||
      thread?.messages?.[thread.messages.length - 1];

    const reply = (replyDrafts[threadKey] || "").trim();
    const imageFile = replyImages[threadKey] || null;
    if (!reply && !imageFile) {
      setError("Please write a reply or choose an image first.");
      return;
    }
    if (!targetMessage?._id) {
      setError("Please select a message to reply.");
      return;
    }

    try {
      setError("");
      const imageUrl = imageFile ? await uploadAdminChatImage(imageFile) : "";
      const updated = await replyToMessage(targetMessage._id, {
        reply: reply || (imageUrl ? "Image" : ""),
        imageUrl,
        messageType: imageUrl ? "image" : "text",
      });
      setUserMessages((prev) =>
        prev.map((item) => {
          if (item._id === targetMessage._id) return updated;
          const sameUser = String(item.user?._id || item.user || item.email || "") === String(targetMessage.user?._id || targetMessage.user || targetMessage.email || "");
          return sameUser ? { ...item, status: "replied" } : item;
        })
      );
      setReplyDrafts((prev) => ({ ...prev, [threadKey]: "" }));
      setReplyImages((prev) => ({ ...prev, [threadKey]: null }));
      setReplyTargets((prev) => ({ ...prev, [threadKey]: "" }));
      setSuccessMessage("Reply sent to user chat.");
    } catch (err) {
      setError(err.message || "Could not send reply");
    }
  };

  const runConfirmAction = async () => {
    const actionData = confirmBox;

    try {
      setConfirmProcessing(true);
      setLoading(true);

      if (actionData.type === "deleteUser") {
        await deleteUser(actionData.id);
        setUsers((prev) => prev.filter((user) => user._id !== actionData.id));
        setSuccessMessage("User deleted successfully.");
      } else if (actionData.type === "deleteProduct") {
        await deleteProduct(actionData.id);
        setProducts((prev) => prev.filter((product) => product._id !== actionData.id));
        setSuccessMessage("Product deleted successfully.");
      } else if (actionData.type === "disputePayment") {
        await executePaymentAction(actionData.dispute, actionData.action);
      } else if (actionData.type === "manualPartialRefund") {
        await executeManualPartialRefundStatus(actionData.dispute);
      } else if (actionData.type === "rejectDispute") {
        await executeRejectDispute(actionData.dispute);
      } else if (actionData.type === "logout") {
        onLogout();
        return;
      }

      setConfirmBox((prev) => ({ ...prev, open: false }));
    } catch (err) {
      setError(err.message || "Action could not be completed");
    } finally {
      setConfirmProcessing(false);
      setLoading(false);
    }
  };




  const isUserBlocked = (user) => user.status === "blocked";

  const handleUserRestrictionToggle = async (user) => {
    const blocked = isUserBlocked(user);
    const nextStatus = blocked ? "active" : "blocked";

    try {
      setLoading(true);
      setError("");

      const updatedRes = await updateUserStatus(user._id, nextStatus);
      const updatedUser = updatedRes.user || updatedRes.account || updatedRes;

      setUsers((prev) =>
        prev.map((item) => (item._id === user._id ? updatedUser : item))
      );

      setSuccessMessage(
        blocked
          ? "User account unrestricted successfully."
          : "User account restricted successfully."
      );
    } catch (err) {
      setError(err.message || "Could not update user account status");
    } finally {
      setLoading(false);
    }
  };

  const renderOverview = () => (
    <div className="admin-tab-content">
      <section className="admin-hero-card">
        <div>
          <p className="admin-eyebrow">SkyBridge Admin Control Center</p>
          <h1>The Ultimate Workspace for Admins.</h1>
          <span>
            Manage your SkyBridge platform with clearer navigation, stronger visuals and smoother control over the full admin flow.
          </span>
        </div>

      </section>

      <section className="admin-kpi-grid">
        <KPI icon={<FaBoxOpen />} label="Active Products" value={activeProductsCount} hint={`${inactiveProductsCount} products currently inactive`} accent="orange" />
        <KPI icon={<FaUsers />} label="Registered Users" value={users.length} hint={`${adminUsersCount} admin account exists`} accent="blue" />
        <KPI icon={<FaTriangleExclamation />} label="Filed Disputes" value={filedDisputesCount} hint={inProgressDisputesCount > 0 ? `${inProgressDisputesCount} dispute case${inProgressDisputesCount > 1 ? "s" : ""} in progress` : "Customer dispute cases"} accent="purple" />
        <KPI
          icon={<FaMessage />}
          label="Messages"
          value={totalChatsCount}
          hint={
            unreadMessagesCount > 0
              ? `${unreadMessagesCount} pending message${unreadMessagesCount > 1 ? "s" : ""}`
              : "Customer conversations"
          }
          accent="green"
        />
      </section>

      <section className="admin-overview-grid">
        <SnapshotCard
          title="Quick product snapshot"
          description="See total, active and inactive products right now."
          buttonText="Manage Products"
          onButtonClick={() => setActiveTab("products")}
          stats={[
            { label: "Total Products", value: products.length },
            { label: "Active Products", value: activeProductsCount },
            { label: "Inactive Products", value: inactiveProductsCount },
          ]}
        />
        <SnapshotCard
          title="Quick dispute snapshot"
          description="See total, open and closed disputes right now."
          buttonText="View Disputes"
          onButtonClick={() => setActiveTab("disputes")}
          stats={[
            { label: "Total Disputes", value: filedDisputesCount },
            { label: "Open Disputes", value: (disputeStatusSummary[0]?.value || 0) + (disputeStatusSummary[1]?.value || 0) },
            { label: "Closed Disputes", value: (disputeStatusSummary[2]?.value || 0) + (disputeStatusSummary[3]?.value || 0) },
          ]}
        />
      </section>
    </div>
  );
  const renderProducts = () => (
    <div className="admin-tab-content">
      <section className="admin-panel-card full" style={{ paddingBottom: 18 }}>
        <div className="admin-panel-head with-toolbar">
          <div>
            <h3>Manage Products</h3>
            <p>Add, edit and disable SkyBridge products from the Products collection.</p>
          </div>

          <div className="admin-toolbar">
            <input
              className="admin-search-input"
              type="text"
              value={productSearch}
              onChange={(e) => setProductSearch(e.target.value)}
              placeholder="Search product by name, store or category"
              style={{ width: 300 }}
            />
            <button className="admin-primary-btn" onClick={openAddProductModal}>
              <FaPlus /> Add New Product
            </button>
          </div>
        </div>

        <div className="admin-table-wrap" style={{ paddingBottom: 16 }}>
          <table className="admin-data-table" style={{ tableLayout: "fixed", width: "100%" }}>
            <colgroup>
              <col style={{ width: "35%" }} />
              <col style={{ width: "13%" }} />
              <col style={{ width: "13%" }} />
              <col style={{ width: "13%" }} />
              <col style={{ width: "13%" }} />
              <col style={{ width: "13%" }} />
            </colgroup>

            <thead>
              <tr>
                <th>Product Details</th>
                <th style={{ textAlign: "center" }}>Category</th>
                <th style={{ textAlign: "center" }}>Status</th>
                <th style={{ textAlign: "center" }}>Weight</th>
                <th style={{ textAlign: "center" }}>Price</th>
                <th style={{ textAlign: "center" }}>Actions</th>
              </tr>
            </thead>

            <tbody>
              {filteredProducts.map((product) => {
                const productName = product.name || "Untitled Product";
                const category = productCategoryLabel(product.category);
                const storeName = product.storeName || "—";
                const weight = product.weight || "—";
                const productImage = product.image || PRODUCT_FALLBACK_IMAGE;

                return (
                  <tr key={product._id}>
                    <td>
                      <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
                        <img
                          src={productImage}
                          alt={productName}
                          loading="lazy"
                          onError={(e) => {
                            e.currentTarget.onerror = null;
                            e.currentTarget.src = PRODUCT_FALLBACK_IMAGE;
                          }}
                          style={{
                            width: 52,
                            height: 52,
                            objectFit: "cover",
                            borderRadius: 14,
                            background: "#f3f4f6",
                            border: "1px solid rgba(148, 163, 184, 0.25)",
                          }}
                        />

                        <div className="admin-table-title-block">
                          <strong>{productName}</strong>
                          <span>{storeName}</span>
                        </div>
                      </div>
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      {category}
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      <StatusBadge value={product.status || "active"} type="product" />
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      {weight}
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      {formatMoney(product.price)}
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      <div className="admin-row-actions" style={{ justifyContent: "center" }}>
                        <button className="icon-btn edit" onClick={() => openEditProductModal(product)}>
                          <FaPenToSquare />
                        </button>
                        <button className="icon-btn delete" onClick={() => askDeleteProduct(product._id)}>
                          <FaTrash />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}

              {!filteredProducts.length && (
                <tr>
                  <td colSpan="6" className="admin-empty-row">
                    No products found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );

  const renderUsers = () => (
    <div className="admin-tab-content">
      <section className="admin-user-summary-grid">
        <KPI icon={<FaUsers />} label="Total Users" value={users.length} hint="All accounts in the system" accent="blue" />
        <KPI icon={<FaCircle />} label="Admins" value={adminUsersCount} hint="Can access admin dashboard" accent="purple" />
        <KPI icon={<FaUser />} label="Buyers/Travelers" value={users.length - adminUsersCount} hint="Standard user accounts" accent="green" />
      </section>

      <section className="admin-panel-card full">
        <div className="admin-panel-head with-toolbar">
          <div>
            <h3>Manage Users</h3>
            <p>Restrict user app access and remove users when needed.</p>
          </div>

          <div className="admin-toolbar">
            <input
              className="admin-search-input admin-user-search-input"
              type="text"
              value={userSearch}
              onChange={(e) => setUserSearch(e.target.value)}
              placeholder="Search user by name, email or role"
            />
          </div>
        </div>

        <div className="admin-table-wrap">
          <table className="admin-data-table" style={{ tableLayout: "fixed", width: "100%" }}>
            <colgroup>
              <col style={{ width: "25%" }} />
              <col style={{ width: "25%" }} />
              <col style={{ width: "15%" }} />
              <col style={{ width: "15%" }} />
              <col style={{ width: "13%" }} />
              <col style={{ width: "17%" }} />
            </colgroup>

            <thead>
              <tr>
                <th>User Info</th>
                <th style={{ textAlign: "left" }}>Email</th>
                <th style={{ textAlign: "center" }}>Role</th>
                <th style={{ textAlign: "center" }}>Status</th>
                <th style={{ textAlign: "center" }}>Joined</th>
                <th style={{ textAlign: "center" }}>Actions</th>
              </tr>
            </thead>

            <tbody>
              {filteredUsers.map((user) => {
                const blocked = user.status === "blocked";
                const isAdmin = user.role === "admin";
                const userInitial = (user.name || user.email || "U").charAt(0).toUpperCase();

                return (
                  <tr key={user._id}>
                    <td>
                      <div className="admin-user-info-cell">
                        {isAdmin ? (
                          <div className="admin-user-avatar admin">
                            <FaCrown />
                          </div>
                        ) : user.profilePicUrl ? (
                          <img
                            className="admin-user-avatar image"
                            src={user.profilePicUrl}
                            alt={user.name || "User"}
                            onError={(e) => {
                              e.currentTarget.style.display = "none";
                            }}
                          />
                        ) : (
                          <div className="admin-user-avatar">
                            {userInitial}
                          </div>
                        )}

                        <div className="admin-table-title-block">
                          <strong>{user.name || "Unnamed User"}</strong>
                          <span>{user._id?.slice(-6).toUpperCase()}</span>
                        </div>
                      </div>
                    </td>

                    <td style={{ textAlign: "left", verticalAlign: "middle" }}>
                      <span className="admin-user-email" title={user.email || ""}>
                        {user.email || "—"}
                      </span>
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      <StatusBadge value={user.role} type="user" />
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      <span className={`admin-user-lock-status ${blocked ? "blocked" : "active"}`}>
                        {blocked ? "Restricted" : "Active"}
                      </span>
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      {formatDate(user.createdAt)}
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      <div className="admin-row-actions" style={{ justifyContent: "center" }}>
                        {!isAdmin ? (
                          <>
                            <button
                              className={`icon-btn ${blocked ? "edit" : "delete"}`}
                              onClick={() => handleUserRestrictionToggle(user)}
                              title={blocked ? "Unrestrict user app access" : "Restrict user app access"}
                            >
                              {blocked ? <FaUserCheck /> : <FaUserSlash />}
                            </button>

                            <button
                              className="icon-btn delete"
                              onClick={() => askDeleteUser(user._id)}
                              title="Delete user"
                            >
                              <FaTrash />
                            </button>
                          </>
                        ) : (
                          <span className="admin-user-lock-status active">
                            Protected
                          </span>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}

              {!filteredUsers.length && (
                <tr>
                  <td colSpan="6" className="admin-empty-row">No users found.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
  const reportCircleItems = [
    { label: "Pending", value: disputeStatusSummary.find((item) => item.label === "Pending")?.value || 0, total: Math.max(filedDisputesCount, 1), className: "orange" },
    { label: "Resolved", value: disputeStatusSummary.find((item) => item.label === "Resolved")?.value || 0, total: Math.max(filedDisputesCount, 1), className: "green" },
    { label: "Rejected", value: disputeStatusSummary.find((item) => item.label === "Rejected")?.value || 0, total: Math.max(filedDisputesCount, 1), className: "blue" },
  ];

  const renderDisputes = () => (
    <div className="admin-tab-content">
      <section className="admin-circle-report-grid">
        {reportCircleItems.map((item) => {
          const percent = Math.min(100, Math.round((item.value / item.total) * 100));
          return (
            <div key={item.label} className="admin-circle-card">
              <div className={`admin-progress-ring ${item.className}`} style={{ "--percent": percent }}>
                <div>
                  <strong>{item.value}</strong>
                  <span>{percent}%</span>
                </div>
              </div>
              <div>
                <h4>{item.label}</h4>
                <p>Dispute status share</p>
              </div>
            </div>
          );
        })}
      </section>

      <section className="admin-panel-card full">
        <div className="admin-panel-head with-toolbar">
          <div>
            <h3>Dispute Management</h3>
            <p>Manage dispute cases in one row like product and user records.</p>
          </div>

          <div className="admin-toolbar">
            <input
              className="admin-search-input"
              type="text"
              value={disputeSearch}
              onChange={(e) => setDisputeSearch(e.target.value)}
              placeholder="Search disputes by order ID or nature"
              style={{ width: 300 }}
            />
            <select className="admin-select-filter" value={disputeFilter} onChange={(e) => setDisputeFilter(e.target.value)}>
              <option value="all">All disputes</option>
              <option value="under_review">Pending</option>
              <option value="resolved">Resolved</option>
              <option value="rejected">Rejected</option>

            </select>
          </div>
        </div>

        <div className="admin-table-wrap" style={{ paddingBottom: 16 }}>
          <table className="admin-data-table" style={{ tableLayout: "fixed", width: "100%" }}>
            <colgroup>
              <col style={{ width: "14%" }} />
              <col style={{ width: "10%" }} />
              <col style={{ width: "16%" }} />
              <col style={{ width: "12%" }} />
              <col style={{ width: "10%" }} />
              <col style={{ width: "7%" }} />
              <col style={{ width: "7%" }} />
              <col style={{ width: "15%" }} />
            </colgroup>

            <thead>
              <tr>
                <th>Dispute Filer</th>
                <th style={{ textAlign: "center" }}>Order ID</th>
                <th style={{ textAlign: "center" }}>Nature of Dispute</th>
                <th style={{ textAlign: "center" }}>Total Amount</th>
                <th style={{ textAlign: "center" }}>Status</th>
                <th style={{ textAlign: "center" }}>Message</th>
                <th style={{ textAlign: "center" }}>Details</th>
                <th style={{ textAlign: "center" }}>Payment</th>
              </tr>
            </thead>

            <tbody>
              {filteredDisputes.map((dispute) => {
                const disputeId = String(dispute._id || dispute.id || "");
                const filer = getDisputeFilerInfo(dispute);
                const orderNumber = getDisputeOrderNumber(dispute);
                const issue = getDisputeIssueInfo(dispute);
                const status = normalizeDisputeStatus(dispute.status);
                const isFinal = ["resolved", "rejected", "cancelled", "closed"].includes(status);
                const money = getDisputeMoneyInfo(dispute);
                return (
                  <tr key={disputeId || orderNumber}>
                    <td style={{ textAlign: "left", verticalAlign: "middle" }}>
                      <div className="admin-table-title-block compact" style={{ alignItems: "flex-start", textAlign: "left" }}>
                        <strong>{filer.name}</strong>
                        <span>{filer.role}</span>
                      </div>
                    </td>
                    <td
                      style={{
                        textAlign: "center",
                        verticalAlign: "middle",
                        fontWeight: 800,
                        color: "#475569",
                        letterSpacing: "0.04em",
                      }}
                    >
                      #{shortId(orderNumber, 6)}
                    </td>
                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      {issue.nature}
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle", fontWeight: 800 }}>
                      {money.totalCostPaid}
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", width: "100%" }}>
                        <StatusBadge value={formatDisputeStatus(status)} type="dispute" />
                      </div>
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", width: "100%" }}>
                        <button
                          type="button"
                          className="icon-btn edit"
                          title="Open filer chat"
                          onClick={() => handleOpenDisputeChat(dispute)}
                        >
                          <FaMessage />
                        </button>
                      </div>
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", width: "100%" }}>
                        <button
                          type="button"
                          className="icon-btn edit"
                          title="View dispute details"
                          onClick={() => setSelectedDisputeDetail(dispute)}
                        >
                          <FaEye />
                        </button>
                      </div>
                    </td>

                    <td style={{ textAlign: "center", verticalAlign: "middle" }}>
                      <button
                        type="button"
                        className="admin-link-btn"
                        title={isFinal ? "Payment already handled" : "Handle payment"}
                        disabled={isFinal}
                        onClick={() => {
                          if (!isFinal) setSelectedPaymentDispute(dispute);
                        }}
                        style={{ minWidth: 118, justifyContent: "center", opacity: isFinal ? 0.55 : 1, cursor: isFinal ? "not-allowed" : "pointer" }}
                      >
                        Handle Payment
                      </button>
                    </td>
                  </tr>
                );
              })}

              {!filteredDisputes.length && (
                <tr>
                  <td colSpan="8" className="admin-empty-row">
                    No disputes found.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );


  const renderMessages = () => {
    const activeThread = chatThreads.find((thread) => thread.key === selectedThreadKey) || chatThreads[0];
    const selectedId = activeThread ? replyTargets[activeThread.key] : "";
    const selectedMessage = activeThread?.messages.find((message) => message._id === selectedId);

    return (
      <div className="admin-tab-content">
        <section className="admin-panel-card full admin-chat-panel admin-single-chat-panel">
          <div className="admin-panel-head">
            <div>
              <h3>User Message Center</h3>
              <p>Select a user once, then double click any message to reply like a clean SMS chat.</p>
            </div>
            <button className="admin-link-btn" onClick={loadAdminData}>Refresh Messages</button>
          </div>

          {!chatThreads.length ? (
            <p className="admin-empty-inline">No user messages yet.</p>
          ) : (
            <div className="admin-whatsapp-chat-layout">
              <aside className="admin-chat-users-list">
                {chatThreads.map((thread) => (
                  <button
                    key={thread.key}
                    type="button"
                    className={`admin-chat-user-item ${activeThread?.key === thread.key ? "active" : ""}`.trim()}
                    onClick={() => setSelectedThreadKey(thread.key)}
                  >
                    <span className="admin-chat-avatar">{(thread.name || "U").charAt(0).toUpperCase()}</span>
                    <span className="admin-chat-user-meta">
                      <strong>{thread.name}</strong>
                      <small>{thread.email}</small>
                    </span>
                    {thread.hasNew && <span className="admin-chat-new-dot">New</span>}
                  </button>
                ))}
              </aside>

              <div className="admin-chat-conversation-card">
                <div className="admin-chat-conversation-head">
                  <div className="admin-chat-avatar large">{(activeThread?.name || "U").charAt(0).toUpperCase()}</div>
                  <div>
                    <strong>{activeThread?.name}</strong>
                    <span>{activeThread?.email}</span>
                  </div>
                  <StatusBadge value={activeThread?.hasNew ? "new" : "replied"} type="message" />
                </div>

                <div className="admin-chat-window single-thread full-conversation">
                  {activeThread?.messages.map((item) => (
                    <React.Fragment key={item._id}>
                      <div
                        className={`admin-chat-bubble user ${selectedId === item._id ? "selected" : ""}`.trim()}
                        onDoubleClick={() => setReplyTargets((prev) => ({ ...prev, [activeThread.key]: item._id }))}
                        title="Double click to reply to this message"
                      >
                        <span>{item.name || "User"}</span>
                        {item.imageUrl && <img className="admin-chat-image" src={item.imageUrl} alt="Message attachment" />}
                        {item.message && item.message !== "Image" && <p>{item.message}</p>}
                      </div>
                      {item.replies?.map((reply) => (
                        <div key={reply._id || reply.createdAt} className="admin-chat-bubble admin">
                          <span>Support</span>
                          {reply.imageUrl && <img className="admin-chat-image" src={reply.imageUrl} alt="Message attachment" />}
                          {reply.message && reply.message !== "Image" && <p>{reply.message}</p>}
                        </div>
                      ))}
                    </React.Fragment>
                  ))}
                </div>

                {selectedMessage && (
                  <div className="admin-reply-target">Replying to: {selectedMessage.message || (selectedMessage.imageUrl ? "Image" : "Selected message")}</div>
                )}

                <div className="admin-reply-row chat-compose">
                  <input
                    type="text"
                    value={replyDrafts[activeThread?.key] || ""}
                    onChange={(e) => setReplyDrafts((prev) => ({ ...prev, [activeThread.key]: e.target.value }))}
                    placeholder="Double click a message, then write reply"
                  />
                  <label className={`admin-image-upload-btn icon-only ${replyImages[activeThread?.key] ? "has-image" : ""}`.trim()} title="Attach image">
                    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                      <path d="M5 5h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Zm0 2v10h14V7H5Zm3 8 2.4-3 1.8 2.2 2.3-3.2L18 15H8Zm1-5.5A1.5 1.5 0 1 1 9 6.5a1.5 1.5 0 0 1 0 3Z" />
                    </svg>
                    <input
                      type="file"
                      accept="image/*"
                      onChange={(e) => setReplyImages((prev) => ({ ...prev, [activeThread.key]: e.target.files?.[0] || null }))}
                    />
                  </label>
                  <button className="admin-primary-btn" type="button" onClick={() => handleAdminReply(activeThread.key)}>Send Reply</button>
                </div>
              </div>
            </div>
          )}
        </section>
      </div>
    );
  };

  return (
    <div className={`admin-dashboard-shell ${sidebarOpen ? "sidebar-open" : "sidebar-collapsed"}`.trim()}>
      <aside
        className="admin-sidebar"
        style={{
          height: "calc(100vh - 85px)",
          minHeight: "calc(100vh - 85px)",
          maxHeight: "calc(100vh - 85px)",
          marginTop: 2,
          marginBottom: 2,
          paddingTop: 25,
          paddingBottom: 25,


        }}
      >
        <div className="admin-sidebar-head">
          <div className="admin-brand-block sidebar-brand">
            <div className="admin-brand-logo">S</div>
            {sidebarOpen && (
              <div>
                <h2>SkyBridge </h2>
                <p> Management System</p>
              </div>
            )}
          </div>
          <button className="admin-toggle-btn" onClick={() => setSidebarOpen((prev) => !prev)}>
            {sidebarOpen ? <FaXmark /> : <FaBars />}
          </button>
        </div>

        <div className="admin-sidebar-profile">
          <div className="admin-profile-avatar">{(currentAdmin?.name || "A").charAt(0).toUpperCase()}</div>
          {sidebarOpen && (
            <div>
              <strong>{currentAdmin?.name || "Admin"}</strong>
              <span>{currentAdmin?.email || "admin@skybridge.com"}</span>
            </div>
          )}
        </div>

        <nav className="admin-side-nav">
          {TAB_ITEMS.map((item) => (
            <button
              key={item.key}
              className={activeTab === item.key ? "active" : ""}
              onClick={() => setActiveTab(item.key)}
              title={item.label}
            >
              <span className="admin-nav-icon">{item.icon}</span>
              {sidebarOpen && (
                <>
                  <span>{item.label}</span>
                  <FaChevronRight className="admin-nav-arrow" />
                </>
              )}
            </button>
          ))}
        </nav>

        <div className="admin-sidebar-footer">
          <button className="admin-sidebar-logout" onClick={() => setConfirmBox({ open: true, type: "logout", id: null, title: "Logout from admin panel?", message: "You will be signed out from the admin session." })}>
            {sidebarOpen ? "Logout" : "↗"}
          </button>
        </div>
      </aside>

      <div className="admin-main-area">
        <header className="admin-topbar">
          <div className="admin-topbar-main">
            <button className="admin-mobile-menu" onClick={() => setSidebarOpen((prev) => !prev)}>
              <FaBars />
            </button>
            <div>
              <p className="admin-page-tag">Control Panel</p>
              <h2>{TAB_ITEMS.find((item) => item.key === activeTab)?.label || "Dashboard"}</h2>
            </div>
          </div>

          <div className="admin-topbar-right" ref={adminTopbarActionsRef}>
            <div className="admin-action-dropdown-wrap">
              <button className="admin-icon-circle has-badge" type="button" onClick={() => { setShowNotifications((prev) => !prev); setShowSettings(false); }}>
                <FaBell />
                {unreadMessagesCount > 0 && <span>{unreadMessagesCount}</span>}
              </button>
              {showNotifications && (
                <div className="admin-action-dropdown">
                  <h4>Notifications</h4>
                  {notificationItems.map((item) => <button key={item} type="button" onClick={() => { setActiveTab(item.includes("SMS") ? "messages" : item.includes("message") ? "messages" : item.includes("dispute") ? "disputes" : "overview"); setShowNotifications(false); }}>{item}</button>)}
                </div>
              )}
            </div>

            <div className="admin-action-dropdown-wrap">
              <button className="admin-icon-circle" type="button" onClick={() => { setShowSettings((prev) => !prev); setShowNotifications(false); }}><FaGear /></button>
              {showSettings && (
                <div className="admin-action-dropdown settings">
                  <h4>Quick Settings</h4>
                  <button type="button" onClick={() => setSidebarOpen((prev) => !prev)}>{sidebarOpen ? "Collapse sidebar" : "Expand sidebar"}</button>
                  <button type="button" onClick={loadAdminData}>Refresh dashboard data</button>
                </div>
              )}
            </div>
            <button className="admin-logout-btn" onClick={() => setConfirmBox({ open: true, type: "logout", id: null, title: "Logout from admin panel?", message: "You will be signed out from the admin session." })}>Logout</button>
          </div>
        </header>

        <main className="admin-content-area">
          {(loading || error || successMessage) && (
            <div className="admin-feedback-strip">
              {loading && <span className="loading">Refreshing admin data...</span>}
              {!loading && error && <span className="error">{error}</span>}
              {!loading && !error && successMessage && <span className="success">{successMessage}</span>}
            </div>
          )}

          {activeTab === "overview" && renderOverview()}
          {activeTab === "products" && renderProducts()}
          {activeTab === "users" && renderUsers()}
          {activeTab === "disputes" && renderDisputes()}
          {activeTab === "messages" && renderMessages()}
        </main>
      </div>


      {isProductModalOpen && (
        <div className="admin-drawer-backdrop" onClick={() => setIsProductModalOpen(false)}>
          <div className="admin-drawer wide polished" style={{ width: "min(1000px, calc(100% - 28px))", paddingBottom: "40px", }} onClick={(e) => e.stopPropagation()}>
            <div className="admin-drawer-head">
              <div>
                <span className="admin-modal-chip">Product Editor</span>
                <h3>{productModalMode === "add" ? "Add New Product" : "Edit Product"}</h3>
                <p>Control product visibility, store name, category, weight and dollar pricing with a cleaner editor.</p>
              </div>
              <div
                className="admin-product-modal-actions"
                style={{ display: "flex", alignItems: "center", gap: 12 }}
              >
                <button
                  type="submit"
                  form="admin-product-editor-form"
                  className="admin-primary-btn"
                  title="Save product"
                  aria-label="Save product"
                  style={{ width: 54, height: 46, padding: 0, borderRadius: 16, fontSize: 20, display: "inline-flex", alignItems: "center", justifyContent: "center" }}
                >
                  <FaCheck />
                </button>
                <button
                  type="button"
                  className="admin-drawer-close"
                  onClick={() => setIsProductModalOpen(false)}
                  title="Close editor"
                  aria-label="Close editor"
                  style={{ width: 54, height: 46, fontSize: 22, display: "inline-flex", alignItems: "center", justifyContent: "center" }}
                >
                  <FaXmark />
                </button>
              </div>
            </div>
            <div className="admin-package-builder-grid" style={{ gap: 30, alignItems: "flex-start" }}>
              <form id="admin-product-editor-form" className="admin-drawer-form two-col" onSubmit={handleProductSubmit}>
                <label>
                  Product Name
                  <input type="text" name="name" value={productForm.name} onChange={handleProductInputChange} required minLength="2" />
                </label>
                <label>
                  Store Name
                  <input type="text" name="storeName" value={productForm.storeName} onChange={handleProductInputChange} required minLength="2" />
                </label>
                <label>
                  Price ($)
                  <input type="number" name="price" value={productForm.price} onChange={handleProductInputChange} required min="0.01" step="any" />
                </label>
                <label>
                  Weight
                  <input type="number" name="weight" value={productForm.weight} onChange={handleProductInputChange} required min="0.01" max="20" step="any" />
                </label>
                <label>
                  Status
                  <select name="status" value={productForm.status} onChange={handleProductInputChange}>
                    <option value="active">Active</option>
                    <option value="inactive">Inactive</option>
                  </select>
                </label>
                <label>
                  Category
                  <select name="category" value={productForm.category} onChange={handleProductInputChange} required>
                    <option value="">Select Category</option>
                    {PRODUCT_CATEGORY_OPTIONS.map((category) => (
                      <option key={category.value} value={category.value}>
                        {category.label}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="full-row">
                  Image URL
                  <input
                    type="text"
                    name="image"
                    value={productForm.image}
                    onChange={handleProductInputChange}
                    placeholder="https://example.com/product-image.jpg"
                    required
                    pattern={PRODUCT_URL_PATTERN}
                    title={PRODUCT_URL_TITLE}
                  />
                </label>
                <label className="full-row">
                  Product URL
                  <input
                    type="text"
                    name="storeLink"
                    value={productForm.storeLink}
                    onChange={handleProductInputChange}
                    placeholder="https://example.com/product-page"
                    required
                    pattern={PRODUCT_URL_PATTERN}
                    title={PRODUCT_URL_TITLE}
                  />
                </label>
              </form>

              <aside className="admin-package-preview-card" style={{ width: 280, alignSelf: "flex-start", overflow: "visible" }}>
                <span className="admin-modal-chip subtle">Live Preview</span>
                <div
                  className="admin-preview-image"
                  style={{ backgroundImage: `url(${productForm.image || PRODUCT_FALLBACK_IMAGE})`, height: 165 }}
                />
                <div className="admin-preview-body">
                  <div className="admin-preview-head">
                    <h4>{productForm.name || "Product Name"}</h4>

                    <div className="admin-preview-subhead">
                      <p>{productForm.storeName || "Store name"}</p>


                    </div>
                  </div>
                  <div className="admin-preview-metrics">
                    <div><span>Price</span><strong>{formatMoney(productForm.price || 0)}</strong></div>
                    <div><span>Weight</span><strong>{productForm.weight || 0}</strong></div>
                  </div>
                  <div className="admin-preview-tags">
                    <span>{productForm.category ? productCategoryLabel(productForm.category) : "Product category"}</span>
                    <span>{productForm.status === "inactive" ? "Hidden from users" : "Visible to users"}</span>
                  </div>
                </div>
              </aside>
            </div>
          </div>
        </div>
      )}

      {selectedDisputeDetail && (() => {
        const filer = getDisputeFilerInfo(selectedDisputeDetail);
        const issue = getDisputeIssueInfo(selectedDisputeDetail);
        const status = normalizeDisputeStatus(selectedDisputeDetail.status);
        const filedAt = pickText(
          selectedDisputeDetail.createdAt,
          selectedDisputeDetail.date,
          selectedDisputeDetail.updatedAt
        );
        const itemImage = getDisputeItemImage(selectedDisputeDetail);
        const productId = getDisputeProductId(selectedDisputeDetail);
        const orderId = getDisputeOrderNumber(selectedDisputeDetail);
        const money = getDisputeMoneyInfo(selectedDisputeDetail);
        const isShowingEvidence = showDisputeEvidencePreview && Boolean(issue.evidence);
        const previewImage = isShowingEvidence ? issue.evidence : itemImage;
        const previewAlt = isShowingEvidence ? "Dispute evidence" : "Dispute item";
        const detailIsFinal = ["resolved", "rejected", "cancelled", "closed"].includes(status);
        const detailLineStyle = {
          margin: "2px 0",
          color: "#111827",
          fontSize: 12.5,
          lineHeight: 1.32,
          wordBreak: "break-word",
          overflowWrap: "anywhere",
          maxWidth: "100%",
        };

        const labelStyle = { fontWeight: 850, color: "#0f172a" };
        const sectionTitleStyle = {
          margin: "0 0 7px",
          color: "#334155",
          fontSize: 14,
          fontWeight: 900,
        };
        const cardStyle = {
          background: "#f8fafc",
          border: "1px solid #edf2f7",
          borderRadius: 8,
          padding: "9px 12px",
          minWidth: 0,
          boxSizing: "border-box",
          overflow: "hidden",
        };

        return (
          <div
            className="admin-drawer-backdrop"
            onClick={() => setSelectedDisputeDetail(null)}
            style={{
              position: "fixed",
              inset: 0,
              zIndex: 9999,
              display: "flex",
              alignItems: "stretch",
              justifyContent: "flex-end",
              background: "rgba(15, 23, 42, 0.62)",
              padding: "0 0 0 14px",
              overflow: "hidden",
            }}
          >
            <div
              onClick={(e) => e.stopPropagation()}
              style={{
                width: "min(1000px, calc(100% - 275px))",
                height: "100vh",
                maxHeight: "100vh",
                background: "#ffffff",
                borderRadius: "22px 0 0 22px",
                boxShadow: "-24px 0 70px rgba(15, 23, 42, 0.28)",
                overflow: "hidden",
                position: "relative",
              }}
            >
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "space-between",
                  padding: "10px 16px 8px",
                  borderBottom: "0",
                  position: "sticky",
                  top: 0,
                  zIndex: 5,
                  background: "#ffffff",
                }}
              >
                <h3
                  style={{
                    margin: 0,
                    color: "#6478ae",
                    fontSize: 20,
                    fontWeight: 900,
                  }}
                >
                  Dispute Details
                </h3>
                <button
                  type="button"
                  onClick={() => setSelectedDisputeDetail(null)}
                  style={{
                    width: 36,
                    height: 36,
                    border: "1px solid #dbe4ff",
                    borderRadius: 10,
                    background: "#ffffff",
                    color: "#6478ae",
                    fontSize: 24,
                    fontWeight: 900,
                    lineHeight: 1,
                    cursor: "pointer",
                    display: "inline-flex",
                    alignItems: "center",
                    justifyContent: "center",
                    boxShadow: "0 8px 22px rgba(100, 120, 174, 0.16)",
                  }}
                  aria-label="Close dispute details"
                >
                  ×
                </button>
              </div>

              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: "minmax(0, 1fr) 450px",
                  gap: 16,
                  padding: "14px 22px 14px 14px",
                  alignItems: "start",
                  height: "calc(100vh - 54px)",
                  overflow: "hidden",
                }}
              >
                <div style={{ display: "grid", gap: 8, alignContent: "start", minWidth: 0, overflow: "hidden" }}>
                  <div style={cardStyle}>
                    <h4 style={sectionTitleStyle}>User Information</h4>
                    <p style={detailLineStyle}><span style={labelStyle}>Name:</span> {filer.name}</p>
                    <p style={detailLineStyle}><span style={labelStyle}>Email:</span> {filer.email}</p>
                    <p style={detailLineStyle}><span style={labelStyle}>User ID:</span> {filer.id}</p>
                    <p style={detailLineStyle}><span style={labelStyle}>Role:</span> {filer.role}</p>
                  </div>

                  <div style={cardStyle}>
                    <h4 style={sectionTitleStyle}>Dispute Details</h4>
                    <p style={detailLineStyle}><span style={labelStyle}>Date:</span> {formatDateTime(filedAt)}</p>
                    <p style={detailLineStyle}><span style={labelStyle}>Product ID:</span> {productId}</p>
                    <p style={detailLineStyle}><span style={labelStyle}>Order ID:</span> {orderId}</p>
                    <p style={detailLineStyle}><span style={labelStyle}>Nature of Dispute:</span> {issue.nature}</p>
                    <p style={detailLineStyle}><span style={labelStyle}>Item Description:</span> {issue.item}</p>
                    <p style={detailLineStyle}><span style={labelStyle}>Total Paid:</span> {money.totalCostPaid}</p>
                    <p style={detailLineStyle}><span style={labelStyle}>Reward:</span> {money.reward}</p>
                    <p
                      title={issue.details}
                      style={{
                        margin: "7px 0 0",
                        color: "#111827",
                        fontSize: 12.5,
                        lineHeight: 1.36,
                        width: "min(470px, 100%)",
                        maxWidth: "470px",
                        whiteSpace: "normal",
                        display: "-webkit-box",
                        WebkitLineClamp: 2,
                        WebkitBoxOrient: "vertical",
                        overflow: "hidden",
                        wordBreak: "break-word",
                        overflowWrap: "anywhere",
                      }}
                    >
                      <span style={labelStyle}>Extra Details:</span> {issue.details}
                    </p>
                    <div style={{ marginTop: 7, display: "flex", alignItems: "center", gap: 10, flexWrap: "wrap" }}>
                      <span style={{ ...labelStyle, fontSize: 14 }}>Status:</span>
                      <StatusBadge value={formatDisputeStatus(status)} type="dispute" />
                      <button
                        type="button"
                        className="admin-link-btn"
                        disabled={detailIsFinal}
                        onClick={() => handleRejectDispute(selectedDisputeDetail)}
                        style={{ padding: "6px 12px", opacity: detailIsFinal ? 0.55 : 1 }}
                      >
                        Reject
                      </button>
                    </div>

                  </div>

                  <div style={cardStyle}>
                    <h4 style={sectionTitleStyle}>Filed Against</h4>

                    <p style={detailLineStyle}>
                      <span style={labelStyle}>Name:</span> {filer.againstName}
                      <button
                        type="button"
                        onClick={() => handleOpenAgainstUserChat(selectedDisputeDetail)}
                        title="Message User"
                        style={{
                          marginLeft: 10,
                          padding: "4px 10px",
                          borderRadius: 999,
                          border: "1px solid #dbeafe",
                          background: "#eff6ff",
                          color: "#6478ae",
                          fontSize: 11,
                          fontWeight: 600,
                          cursor: "pointer",
                          display: "inline-flex",
                          alignItems: "center",
                          gap: 4,
                        }}
                      >
                        <FaMessage style={{ fontSize: 11 }} />
                        Message
                      </button>
                    </p>

                    <p style={detailLineStyle}>
                      <span style={labelStyle}>Email:</span> {filer.againstEmail}
                    </p>

                    <p style={detailLineStyle}><span style={labelStyle}>User ID:</span> {filer.againstId}</p>
                    <p style={detailLineStyle}><span style={labelStyle}>Role:</span> {filer.against}</p>
                  </div>
                </div>

                <aside
                  style={{
                    width: "100%",
                    background: "transparent",
                    border: "0",
                    borderRadius: 10,
                    padding: "14px 20px 0 10px",
                    boxSizing: "border-box",
                    display: "flex",
                    flexDirection: "column",
                    gap: 12,
                    alignSelf: "start",
                    maxWidth: 430,
                    overflow: "hidden",
                  }}
                >
                  <div
                    style={{
                      height: 415,
                      minHeight: 415,
                      maxHeight: 415,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      borderRadius: 8,
                      overflow: "hidden",
                      background: "#ffffff",
                      border: "1px solid #eef2f7",
                    }}
                  >
                    {previewImage ? (
                      <img
                        src={previewImage}
                        alt={previewAlt}
                        style={{
                          width: "100%",
                          height: "100%",
                          maxHeight: 410,
                          objectFit: "contain",
                          borderRadius: 8,
                          display: "block",
                        }}
                      />
                    ) : (
                      <div
                        style={{
                          textAlign: "center",
                          color: "#94a3b8",
                          fontWeight: 800,
                        }}
                      >
                        {isShowingEvidence ? "No Evidence Image" : "No Item Image"}
                      </div>
                    )}
                  </div>

                  <button
                    type="button"
                    className="admin-link-btn"
                    onClick={() => {
                      if (!issue.evidence) {
                        setError("No evidence image found for this dispute.");
                        return;
                      }
                      setShowDisputeEvidencePreview((prev) => !prev);
                    }}
                    style={{
                      width: "86%",
                      height: 44,
                      alignSelf: "center",
                      justifyContent: "center",
                      borderRadius: 18,
                      border: "0",
                      background: "#e3e7ed",
                      color: "#1d4ed8",
                      fontWeight: 900,
                      opacity: 1,
                      cursor: "pointer",
                    }}
                  >
                    {isShowingEvidence ? "View Item Picture" : "View Evidence"}
                  </button>
                </aside>
              </div>
            </div>
          </div>
        );
      })()}

      {selectedPaymentDispute && (() => {
        const status = normalizeDisputeStatus(selectedPaymentDispute.status);
        const isFinal = ["resolved", "rejected", "cancelled", "closed"].includes(status);
        const money = getDisputeMoneyInfo(selectedPaymentDispute);
        const filer = getDisputeFilerInfo(selectedPaymentDispute);

        return (
          <div className="admin-drawer-backdrop" onClick={() => setSelectedPaymentDispute(null)}>
            <div className="admin-drawer" onClick={(e) => e.stopPropagation()}>
              <div className="admin-drawer-head">
                <div>
                  <span className="admin-modal-chip">Dispute Payment</span>
                  <h3>Handle Payment</h3>
                  <p>Select release or full refund. For partial refund, use Stripe Sandbox manually, then mark it as resolved.</p>
                </div>
                <button className="admin-drawer-close" onClick={() => setSelectedPaymentDispute(null)}>×</button>
              </div>

              <div className="admin-drawer-form">
                <div style={{ display: "grid", gap: 10 }}>
                  <div style={{ padding: "12px 14px", border: "1px solid #e5e7eb", borderRadius: 14, background: "#f8fafc" }}>
                    <strong style={{ color: "#0f172a" }}>Dispute Filer</strong>
                    <p style={{ margin: "5px 0 0", color: "#334155" }}>{filer.name}</p>
                    <span style={{ color: "#64748b", fontSize: 12 }}>{filer.role}</span>
                  </div>

                  <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
                    <div style={{ padding: "12px 14px", border: "1px solid #e5e7eb", borderRadius: 14, background: "#ffffff" }}>
                      <strong style={{ color: "#0f172a" }}>Total Paid</strong>
                      <p style={{ margin: "5px 0 0", color: "#334155", fontWeight: 800 }}>{money.totalCostPaid}</p>
                    </div>
                    <div style={{ padding: "12px 14px", border: "1px solid #e5e7eb", borderRadius: 14, background: "#ffffff" }}>
                      <strong style={{ color: "#0f172a" }}>Reward</strong>
                      <p style={{ margin: "5px 0 0", color: "#334155", fontWeight: 800 }}>{money.reward}</p>
                    </div>
                  </div>
                </div>

                <div style={{ marginTop: 14, padding: "12px 14px", border: "1px dashed #cbd5e1", borderRadius: 14, background: "#f8fafc" }}>
                  <strong style={{ color: "#0f172a" }}>Need partial refund?</strong>
                  <p style={{ margin: "5px 0 10px", color: "#475569", fontSize: 12.5 }}>
                    Do the partial refund manually in Stripe Sandbox first. After it is done, use the button below to mark this dispute as Resolved.
                  </p>
                  <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
                    <button
                      type="button"
                      className="admin-link-btn"
                      onClick={() => window.open(STRIPE_SANDBOX_PAYMENTS_URL, "_blank", "noopener,noreferrer")}
                      style={{ justifyContent: "center" }}
                    >
                      Open Stripe Sandbox
                    </button>
                  </div>
                </div>

                <div className="admin-drawer-actions" style={{ flexWrap: "wrap" }}>
                  <button type="button" className="admin-primary-btn" disabled={isFinal} onClick={() => handleManualPartialRefundStatus(selectedPaymentDispute)}>
                    Partial Refund Done
                  </button>
                  <button type="button" className="admin-primary-btn" disabled={isFinal} onClick={() => handlePaymentAction(selectedPaymentDispute, "release_to_traveler")}>
                    Release
                  </button>
                  <button type="button" className="admin-primary-btn" disabled={isFinal} onClick={() => handlePaymentAction(selectedPaymentDispute, "full_refund")}>
                    Full Refund
                  </button>
                </div>
              </div>
            </div>
          </div>
        );
      })()}

      {confirmBox.open && (
        <div className="site-modal-overlay" onClick={() => setConfirmBox((prev) => ({ ...prev, open: false }))}>
          <div className="site-modal-card" onClick={(e) => e.stopPropagation()}>
            <div className="site-modal-icon warning">!</div>
            <h3>{confirmBox.title}</h3>
            <p>{confirmBox.message}</p>
            <div className="site-modal-actions">
              <button className="site-modal-secondary" disabled={confirmProcessing} onClick={() => setConfirmBox((prev) => ({ ...prev, open: false }))}>
                Cancel
              </button>
              <button className="site-modal-primary danger" disabled={confirmProcessing} onClick={runConfirmAction}>
                {confirmProcessing ? "Processing..." : "Continue"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default AdminDashboard;

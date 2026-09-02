// src/api.js
const API_BASE_URL = process.env.REACT_APP_API_URL || "http://localhost:5000";

function getAuthHeaders() {
  const token = localStorage.getItem("token");
  if (!token) return {};

  return {
    Authorization: `Bearer ${token}`,
  };
}

async function request(path, options = {}) {
  const url = `${API_BASE_URL}${path}`;

  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };

  const res = await fetch(url, {
    ...options,
    headers,
  });

  const data = await res.json().catch(() => ({}));

  if (!res.ok) {
    throw new Error(data.message || "Request failed");
  }

  return data;
}

function productToDashboardProduct(product = {}) {
  const id = product._id || product.id;

  return {
    ...product,
    _id: id,
    id,
    name: product.name || "Untitled Product",
    image: product.image || "",
    storeName: product.storeName || "",
    storeLink: product.storeLink || "",
    price: Number(product.price || 0),
    category: product.category || "Product",
    tags: Array.isArray(product.tags) ? product.tags : [],
    weight: Number(product.weight || 0),
    status: product.status || "active",
    createdAt: product.createdAt,
    updatedAt: product.updatedAt,
  };
}

function dashboardProductToData(payload = {}) {
  return {
    name: payload.name,
    image: payload.image,
    storeName: payload.storeName,
    storeLink: payload.storeLink,
    price: payload.price,
    category: payload.category,
    tags: payload.tags,
    weight: payload.weight,
    status: payload.status,
  };
}

function normalizeProductListResponse(data) {
  const list = Array.isArray(data) ? data : data.products || data.data || [];
  const products = list.map(productToDashboardProduct);

  return {
    ...(Array.isArray(data) ? {} : data),
    products,
    count: data?.count ?? products.length,
  };
}

function normalizeProductResponse(data) {
  const product = productToDashboardProduct(data?.product || data?.data || data);

  return {
    ...data,
    product,
    data: product,
  };
}

export function loginUser(payload) {
  return request("/api/auth/login", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateUserStatus(id, status) {
  return request(`/api/accounts/${id}/status`, {
    method: "PATCH",
    headers: getAuthHeaders(),
    body: JSON.stringify({ status }),
  });
}
export function getCurrentUser() {
  return request("/api/auth/me", {
    headers: getAuthHeaders(),
  });
}

export function adminCheck() {
  return request("/api/auth/check", {
    headers: getAuthHeaders(),
  });
}

export function getAllUsers() {
  return request("/api/accounts", {
    headers: getAuthHeaders(),
  });
}

export function deleteUser(id) {
  return request(`/api/accounts/${id}`, {
    method: "DELETE",
    headers: getAuthHeaders(),
  });
}

export async function getAllProducts() {
  const data = await request("/api/listData?collection=Products", {
    headers: getAuthHeaders(),
  });

  return normalizeProductListResponse(data);
}

export async function createProduct(payload) {
  const data = await request("/api/createData", {
    method: "POST",
    headers: getAuthHeaders(),
    body: JSON.stringify({
      collection: "Products",
      data: dashboardProductToData(payload),
    }),
  });

  return normalizeProductResponse(data);
}

export async function updateProduct(id, payload) {
  const data = await request("/api/updateData", {
    method: "POST",
    headers: getAuthHeaders(),
    body: JSON.stringify({
      collection: "Products",
      id,
      data: dashboardProductToData(payload),
    }),
  });

  return normalizeProductResponse(data);
}

export function deleteProduct(id) {
  return request("/api/deleteData", {
    method: "POST",
    headers: getAuthHeaders(),
    body: JSON.stringify({
      collection: "Products",
      id,
    }),
  });
}


// export function updateOrderStatus(id, status) {
//   return request(`/api/orders/${id}/status`, {
//     method: "PUT",
//     headers: getAuthHeaders(),
//     body: JSON.stringify({ status }),
//   });
// }

export function getAdminMessages() {
  return request("/api/messages/admin", {
    headers: getAuthHeaders(),
  });
}

export function replyToMessage(id, reply) {
  const payload = typeof reply === "object" ? reply : { reply };
  return request(`/api/messages/${id}/reply`, {
    method: "POST",
    headers: getAuthHeaders(),
    body: JSON.stringify(payload),
  });
}

export function startAdminChat(payload) {
  return request("/api/messages/admin/start", {
    method: "POST",
    headers: getAuthHeaders(),
    body: JSON.stringify(payload),
  });
}
export function getAllDisputes() {
  return request("/api/disputes", {
    headers: getAuthHeaders(),
  });
}

export function updateDisputeStatus(id, status, extra = {}) {
  const payload = typeof status === "object" && status !== null
    ? status
    : { status, ...extra };

  return request(`/api/disputes/${id}/status`, {
    method: "PUT",
    headers: getAuthHeaders(),
    body: JSON.stringify(payload),
  });
}
export async function handleDisputePayment(disputeId, payload) {
  return request(`/api/disputes/${disputeId}/payment`, {
    method: "POST",
    headers: getAuthHeaders(),
    body: JSON.stringify(payload),
  });
}
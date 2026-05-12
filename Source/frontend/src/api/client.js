const BASE_URL = "http://127.0.0.1:8001/api/v1";
const TOKEN_KEY = "detal.token";

export function getToken() {
    return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token) {
    if (token) localStorage.setItem(TOKEN_KEY, token);
    else localStorage.removeItem(TOKEN_KEY);
}

async function request(path, options = {}) {
    const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
    const token = getToken();
    if (token) headers["Authorization"] = `Bearer ${token}`;

    const response = await fetch(BASE_URL + path, { ...options, headers });
    const text = await response.text();
    let body = null;
    try {
        body = text ? JSON.parse(text) : null;
    } catch {
        throw new Error("Сервер вернул некорректный JSON");
    }
    if (!response.ok) {
        const message = body && body.message ? body.message : `Ошибка ${response.status}`;
        const error = new Error(message);
        error.status = response.status;
        throw error;
    }
    return body && body.data !== undefined ? body.data : body;
}

export const api = {
    login: (login, password) => request("/auth/login", { method: "POST", body: JSON.stringify({ login, password }) }),
    me:    () => request("/auth/me"),

    listDetails:   (params = {}) => {
        const q = new URLSearchParams(params).toString();
        return request("/details" + (q ? "?" + q : ""));
    },
    getDetail:     (id) => request(`/details/${id}`),
    createDetail:  (data) => request("/details", { method: "POST", body: JSON.stringify(data) }),
    updateDetail:  (id, data) => request(`/details/${id}`, { method: "PUT", body: JSON.stringify(data) }),
    deleteDetail:  (id) => request(`/details/${id}`, { method: "DELETE" }),

    listMovements: (limit = 100) => request(`/movements?limit=${limit}`),
    receive:       (data) => request("/movements/receive",  { method: "POST", body: JSON.stringify(data) }),
    issue:         (data) => request("/movements/issue",    { method: "POST", body: JSON.stringify(data) }),
    transfer:      (data) => request("/movements/transfer", { method: "POST", body: JSON.stringify(data) }),
    deleteMovement: (id) => request(`/movements/${id}`, { method: "DELETE" }),

    listCategories: () => request("/categories"),
    listMaterials:  () => request("/materials"),
    listSuppliers:  () => request("/suppliers"),
    listWarehouses: () => request("/warehouses"),

    stockReport:        (params = {}) => {
        const q = new URLSearchParams(params).toString();
        return request("/reports/stock" + (q ? "?" + q : ""));
    },
    lowStockReport:     () => request("/reports/low-stock"),
    supplierReport:     () => request("/reports/suppliers"),
    warehouseValue:     () => request("/reports/warehouse-value"),
    consumptionReport:  (days = 30) => request(`/reports/consumption?days=${days}`),
};

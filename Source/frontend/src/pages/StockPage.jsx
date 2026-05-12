import { useEffect, useState } from "react";
import { api } from "../api/client";

const WH_KEY = "detal.stockWarehouse";

export default function StockPage() {
    const [warehouses, setWarehouses] = useState([]);
    const [warehouseId, setWarehouseId] = useState(localStorage.getItem(WH_KEY) || "");
    const [items, setItems] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");

    useEffect(() => {
        api.listWarehouses()
            .then((d) => setWarehouses(d.items))
            .catch((e) => setError(e.message));
    }, []);

    useEffect(() => {
        setLoading(true);
        localStorage.setItem(WH_KEY, warehouseId);
        const params = warehouseId ? { warehouse_id: warehouseId } : {};
        api.stockReport(params)
            .then((d) => setItems(d.items))
            .catch((e) => setError(e.message))
            .finally(() => setLoading(false));
    }, [warehouseId]);

    return (
        <section>
            <h2 className="page-title">Остатки на складах</h2>
            <div className="filter-row">
                <select className="form-input" value={warehouseId} onChange={(e) => setWarehouseId(e.target.value)}>
                    <option value="">Все склады</option>
                    {warehouses.map((w) => (
                        <option key={w.id} value={w.id}>{w.code} — {w.name}</option>
                    ))}
                </select>
            </div>
            {error && <p className="state-error">{error}</p>}
            {loading ? <p className="state-loading">Загрузка…</p> : (
                <table className="data-table">
                    <thead>
                        <tr>
                            <th>Артикул</th>
                            <th>Наименование</th>
                            <th>Категория</th>
                            <th>Склад</th>
                            <th>Остаток</th>
                        </tr>
                    </thead>
                    <tbody>
                        {items.map((row) => (
                            <tr key={`${row.detail_id}-${row.warehouse_id}`}>
                                <td><code>{row.article}</code></td>
                                <td>{row.detail_name}</td>
                                <td>{row.category_name}</td>
                                <td>{row.warehouse_code} — {row.warehouse_name}</td>
                                <td className={row.balance === 0 ? "muted" : ""}>{row.balance}</td>
                            </tr>
                        ))}
                        {items.length === 0 && (
                            <tr><td colSpan={5} className="empty">Нет данных</td></tr>
                        )}
                    </tbody>
                </table>
            )}
        </section>
    );
}

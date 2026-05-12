import { useEffect, useState } from "react";
import { api } from "../api/client";

export default function ReportsPage() {
    const [low, setLow] = useState([]);
    const [warehouseValues, setWarehouseValues] = useState([]);
    const [suppliers, setSuppliers] = useState([]);
    const [consumption, setConsumption] = useState({ days: 30, items: [] });
    const [days, setDays] = useState(30);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");

    useEffect(() => {
        Promise.all([api.lowStockReport(), api.warehouseValue(), api.supplierReport()])
            .then(([l, w, s]) => {
                setLow(l.items);
                setWarehouseValues(w.items);
                setSuppliers(s.items);
            })
            .catch((e) => setError(e.message))
            .finally(() => setLoading(false));
    }, []);

    useEffect(() => {
        api.consumptionReport(days)
            .then((d) => setConsumption(d))
            .catch((e) => setError(e.message));
    }, [days]);

    if (loading) return <p className="state-loading">Загрузка…</p>;
    if (error) return <p className="state-error">{error}</p>;

    return (
        <section className="reports">
            <h2 className="page-title">Отчёты</h2>

            <div className="report-block">
                <h3 className="report-title">Стоимость остатков по складам</h3>
                <table className="data-table">
                    <thead>
                        <tr><th>Код</th><th>Название</th><th>Стоимость остатка, ₽</th></tr>
                    </thead>
                    <tbody>
                        {warehouseValues.map((w) => (
                            <tr key={w.id}>
                                <td><code>{w.code}</code></td>
                                <td>{w.name}</td>
                                <td>{Number(w.total_value).toLocaleString("ru-RU", { minimumFractionDigits: 2 })}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            <div className="report-block">
                <h3 className="report-title">Детали с остатком ниже минимального</h3>
                {low.length === 0 ? (
                    <p className="muted">Все детали обеспечены в требуемом количестве</p>
                ) : (
                    <table className="data-table">
                        <thead>
                            <tr><th>Артикул</th><th>Наименование</th><th>Минимум</th><th>Текущий остаток</th></tr>
                        </thead>
                        <tbody>
                            {low.map((d) => (
                                <tr key={d.detail_id}>
                                    <td><code>{d.article}</code></td>
                                    <td>{d.detail_name}</td>
                                    <td>{d.min_stock}</td>
                                    <td className="danger">{d.total_balance}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                )}
            </div>

            <div className="report-block">
                <h3 className="report-title">Закупки по поставщикам</h3>
                <table className="data-table">
                    <thead>
                        <tr><th>Поставщик</th><th>Поставок</th><th>Кол-во</th><th>Сумма, ₽</th><th>Последняя поставка</th></tr>
                    </thead>
                    <tbody>
                        {suppliers.map((s) => (
                            <tr key={s.supplier_id}>
                                <td>{s.supplier_name}</td>
                                <td>{s.movement_count}</td>
                                <td>{s.total_qty}</td>
                                <td>{Number(s.total_amount).toLocaleString("ru-RU", { minimumFractionDigits: 2 })}</td>
                                <td>{s.last_purchase_at ? new Date(s.last_purchase_at).toLocaleDateString("ru-RU") : "—"}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            <div className="report-block">
                <h3 className="report-title">Расход деталей за период</h3>
                <div className="filter-row">
                    <label className="form-label">Период (дней):</label>
                    <input className="form-input form-input-narrow" type="number" min="1" value={days}
                           onChange={(e) => setDays(Number(e.target.value) || 30)} />
                </div>
                <table className="data-table">
                    <thead>
                        <tr><th>Артикул</th><th>Наименование</th><th>Списано за период</th></tr>
                    </thead>
                    <tbody>
                        {consumption.items.filter((row) => row.consumed > 0).map((row) => (
                            <tr key={row.id}>
                                <td><code>{row.article}</code></td>
                                <td>{row.name}</td>
                                <td>{row.consumed}</td>
                            </tr>
                        ))}
                        {consumption.items.filter((row) => row.consumed > 0).length === 0 && (
                            <tr><td colSpan={3} className="empty">За выбранный период списаний не было</td></tr>
                        )}
                    </tbody>
                </table>
            </div>
        </section>
    );
}

import { useEffect, useState } from "react";
import { api } from "../api/client";
import Modal from "../components/Modal";

const TYPE_LABELS = {
    IN: "Приход",
    OUT: "Расход",
    TRANSFER_IN: "Перемещение (приход)",
    TRANSFER_OUT: "Перемещение (списание)",
};

export default function MovementsPage() {
    const [items, setItems] = useState([]);
    const [details, setDetails] = useState([]);
    const [warehouses, setWarehouses] = useState([]);
    const [suppliers, setSuppliers] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");
    const [activeForm, setActiveForm] = useState(null);
    const [formError, setFormError] = useState("");
    const [busy, setBusy] = useState(false);

    const [form, setForm] = useState({
        detail_id: "", warehouse_id: "", warehouse_from: "", warehouse_to: "",
        supplier_id: "", quantity: 1, price_per_unit: "", comment: "",
    });

    const reload = () => {
        setLoading(true);
        api.listMovements(100)
            .then((d) => setItems(d.items))
            .catch((e) => setError(e.message))
            .finally(() => setLoading(false));
    };

    useEffect(() => {
        reload();
        Promise.all([api.listDetails(), api.listWarehouses(), api.listSuppliers()])
            .then(([d, w, s]) => {
                setDetails(d.items); setWarehouses(w.items); setSuppliers(s.items);
            })
            .catch((e) => setError(e.message));
    }, []);

    const openForm = (kind) => {
        setActiveForm(kind);
        setFormError("");
        setForm({
            detail_id: "", warehouse_id: "", warehouse_from: "", warehouse_to: "",
            supplier_id: "", quantity: 1, price_per_unit: "", comment: "",
        });
    };

    const closeForm = () => setActiveForm(null);

    const submit = async (e) => {
        e.preventDefault();
        setFormError("");
        setBusy(true);
        try {
            if (activeForm === "receive") {
                await api.receive({
                    detail_id: Number(form.detail_id),
                    warehouse_id: Number(form.warehouse_id),
                    supplier_id: Number(form.supplier_id),
                    quantity: Number(form.quantity),
                    price_per_unit: Number(form.price_per_unit),
                    comment: form.comment || null,
                });
            } else if (activeForm === "issue") {
                await api.issue({
                    detail_id: Number(form.detail_id),
                    warehouse_id: Number(form.warehouse_id),
                    quantity: Number(form.quantity),
                    comment: form.comment || null,
                });
            } else if (activeForm === "transfer") {
                await api.transfer({
                    detail_id: Number(form.detail_id),
                    warehouse_from: Number(form.warehouse_from),
                    warehouse_to: Number(form.warehouse_to),
                    quantity: Number(form.quantity),
                });
            }
            closeForm();
            reload();
        } catch (err) {
            setFormError(err.message);
        } finally {
            setBusy(false);
        }
    };

    return (
        <section>
            <div className="page-head">
                <h2 className="page-title">Движения на складе</h2>
                <div className="btn-group">
                    <button className="btn btn-primary" onClick={() => openForm("receive")}>+ Приход</button>
                    <button className="btn btn-ghost" onClick={() => openForm("issue")}>− Расход</button>
                    <button className="btn btn-ghost" onClick={() => openForm("transfer")}>↔ Перемещение</button>
                </div>
            </div>

            {error && <p className="state-error">{error}</p>}
            {loading ? <p className="state-loading">Загрузка…</p> : (
                <table className="data-table">
                    <thead>
                        <tr>
                            <th>Дата</th>
                            <th>Тип</th>
                            <th>Артикул</th>
                            <th>Наименование</th>
                            <th>Склад</th>
                            <th>Поставщик</th>
                            <th>Кол-во</th>
                            <th>Сумма, ₽</th>
                            <th>Сотрудник</th>
                            <th>Комментарий</th>
                        </tr>
                    </thead>
                    <tbody>
                        {items.map((row) => (
                            <tr key={row.id}>
                                <td>{new Date(row.moved_at).toLocaleString("ru-RU")}</td>
                                <td><span className={`badge badge-${row.movement_type.toLowerCase()}`}>{TYPE_LABELS[row.movement_type] || row.movement_type}</span></td>
                                <td><code>{row.article}</code></td>
                                <td>{row.detail_name}</td>
                                <td>{row.warehouse_code}</td>
                                <td>{row.supplier_name || "—"}</td>
                                <td>{row.quantity}</td>
                                <td>{row.amount ? Number(row.amount).toFixed(2) : "—"}</td>
                                <td>{row.user_name}</td>
                                <td className="muted">{row.comment || ""}</td>
                            </tr>
                        ))}
                        {items.length === 0 && (
                            <tr><td colSpan={10} className="empty">Нет движений</td></tr>
                        )}
                    </tbody>
                </table>
            )}

            {activeForm && (
                <Modal
                    title={
                        activeForm === "receive" ? "Оформить приход" :
                        activeForm === "issue"   ? "Оформить расход" : "Переместить между складами"
                    }
                    onClose={closeForm}
                >
                    <form onSubmit={submit} className="form-grid">
                        {formError && <div className="auth-error">{formError}</div>}

                        <div>
                            <label className="form-label">Деталь</label>
                            <select className="form-input" required value={form.detail_id}
                                    onChange={(e) => setForm({ ...form, detail_id: e.target.value })}>
                                <option value="">— выберите —</option>
                                {details.map((d) => (
                                    <option key={d.id} value={d.id}>{d.article} — {d.name}</option>
                                ))}
                            </select>
                        </div>

                        {activeForm !== "transfer" && (
                            <div>
                                <label className="form-label">Склад</label>
                                <select className="form-input" required value={form.warehouse_id}
                                        onChange={(e) => setForm({ ...form, warehouse_id: e.target.value })}>
                                    <option value="">— выберите —</option>
                                    {warehouses.map((w) => (
                                        <option key={w.id} value={w.id}>{w.code} — {w.name}</option>
                                    ))}
                                </select>
                            </div>
                        )}

                        {activeForm === "transfer" && (
                            <>
                                <div>
                                    <label className="form-label">Склад-источник</label>
                                    <select className="form-input" required value={form.warehouse_from}
                                            onChange={(e) => setForm({ ...form, warehouse_from: e.target.value })}>
                                        <option value="">— выберите —</option>
                                        {warehouses.map((w) => (
                                            <option key={w.id} value={w.id}>{w.code} — {w.name}</option>
                                        ))}
                                    </select>
                                </div>
                                <div>
                                    <label className="form-label">Склад-получатель</label>
                                    <select className="form-input" required value={form.warehouse_to}
                                            onChange={(e) => setForm({ ...form, warehouse_to: e.target.value })}>
                                        <option value="">— выберите —</option>
                                        {warehouses.map((w) => (
                                            <option key={w.id} value={w.id}>{w.code} — {w.name}</option>
                                        ))}
                                    </select>
                                </div>
                            </>
                        )}

                        {activeForm === "receive" && (
                            <>
                                <div>
                                    <label className="form-label">Поставщик</label>
                                    <select className="form-input" required value={form.supplier_id}
                                            onChange={(e) => setForm({ ...form, supplier_id: e.target.value })}>
                                        <option value="">— выберите —</option>
                                        {suppliers.map((s) => (
                                            <option key={s.id} value={s.id}>{s.name}</option>
                                        ))}
                                    </select>
                                </div>
                                <div>
                                    <label className="form-label">Цена за единицу, ₽</label>
                                    <input className="form-input" type="number" step="0.01" min="0" required
                                           value={form.price_per_unit}
                                           onChange={(e) => setForm({ ...form, price_per_unit: e.target.value })} />
                                </div>
                            </>
                        )}

                        <div>
                            <label className="form-label">Количество</label>
                            <input className="form-input" type="number" min="1" required
                                   value={form.quantity}
                                   onChange={(e) => setForm({ ...form, quantity: e.target.value })} />
                        </div>

                        {activeForm !== "transfer" && (
                            <div className="form-grid-full">
                                <label className="form-label">Комментарий</label>
                                <input className="form-input"
                                       value={form.comment}
                                       onChange={(e) => setForm({ ...form, comment: e.target.value })} />
                            </div>
                        )}

                        <div className="form-actions">
                            <button type="button" className="btn btn-ghost" onClick={closeForm}>Отмена</button>
                            <button type="submit" className="btn btn-primary" disabled={busy}>
                                {busy ? "Сохранение…" : "Подтвердить"}
                            </button>
                        </div>
                    </form>
                </Modal>
            )}
        </section>
    );
}

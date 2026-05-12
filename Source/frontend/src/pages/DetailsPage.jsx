import { useEffect, useMemo, useState } from "react";
import { api } from "../api/client";
import Modal from "../components/Modal";
import { useAuth } from "../context/AuthContext";

const SEARCH_KEY = "detal.detailsSearch";

const emptyForm = {
    article: "", name: "", category_id: "", material_id: "",
    weight_kg: "", unit: "шт", price: "", drawing_no: "", min_stock: 0,
};

export default function DetailsPage() {
    const { user } = useAuth();
    const canEdit = user?.role === "admin" || user?.role === "manager";

    const [details, setDetails] = useState([]);
    const [categories, setCategories] = useState([]);
    const [materials, setMaterials] = useState([]);
    const [search, setSearch] = useState(localStorage.getItem(SEARCH_KEY) || "");
    const [categoryId, setCategoryId] = useState("");
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");
    const [modalOpen, setModalOpen] = useState(false);
    const [editing, setEditing] = useState(null);
    const [form, setForm] = useState(emptyForm);
    const [formError, setFormError] = useState("");

    useEffect(() => {
        Promise.all([api.listCategories(), api.listMaterials()])
            .then(([c, m]) => { setCategories(c.items); setMaterials(m.items); })
            .catch((e) => setError(e.message));
    }, []);

    const reload = () => {
        setLoading(true);
        const params = {};
        if (search) params.q = search;
        if (categoryId) params.category_id = categoryId;
        api.listDetails(params)
            .then((data) => setDetails(data.items))
            .catch((e) => setError(e.message))
            .finally(() => setLoading(false));
    };

    useEffect(() => {
        localStorage.setItem(SEARCH_KEY, search);
        const t = setTimeout(reload, 200);
        return () => clearTimeout(t);
    }, [search, categoryId]);

    const openCreate = () => {
        setEditing(null);
        setForm(emptyForm);
        setFormError("");
        setModalOpen(true);
    };

    const openEdit = (detail) => {
        setEditing(detail);
        setForm({
            article: detail.article,
            name: detail.name,
            category_id: detail.category_id,
            material_id: detail.material_id,
            weight_kg: detail.weight_kg,
            unit: detail.unit,
            price: detail.price,
            drawing_no: detail.drawing_no || "",
            min_stock: detail.min_stock,
        });
        setFormError("");
        setModalOpen(true);
    };

    const closeModal = () => { setModalOpen(false); setEditing(null); setForm(emptyForm); };

    const submitForm = async (e) => {
        e.preventDefault();
        setFormError("");
        const payload = {
            ...form,
            category_id: Number(form.category_id),
            material_id: Number(form.material_id),
            weight_kg: Number(form.weight_kg),
            price: Number(form.price),
            min_stock: Number(form.min_stock),
        };
        try {
            if (editing) await api.updateDetail(editing.id, payload);
            else await api.createDetail(payload);
            closeModal();
            reload();
        } catch (err) {
            setFormError(err.message);
        }
    };

    const removeDetail = async (id) => {
        if (!confirm("Удалить деталь? Это действие необратимо.")) return;
        try {
            await api.deleteDetail(id);
            reload();
        } catch (err) {
            alert(err.message);
        }
    };

    const visible = useMemo(() => details, [details]);

    return (
        <section>
            <div className="page-head">
                <h2 className="page-title">Каталог деталей</h2>
                {canEdit && <button className="btn btn-primary" onClick={openCreate}>+ Добавить деталь</button>}
            </div>

            <div className="filter-row">
                <input className="form-input"
                       placeholder="Поиск по артикулу или наименованию"
                       value={search}
                       onChange={(e) => setSearch(e.target.value)} />
                <select className="form-input" value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
                    <option value="">Все категории</option>
                    {categories.map((c) => (
                        <option key={c.id} value={c.id}>{"   ".repeat(c.parent_id ? 1 : 0)}{c.name}</option>
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
                            <th>Материал</th>
                            <th>Масса, кг</th>
                            <th>Цена, ₽</th>
                            <th>Мин. остаток</th>
                            <th></th>
                        </tr>
                    </thead>
                    <tbody>
                        {visible.map((d) => (
                            <tr key={d.id}>
                                <td><code>{d.article}</code></td>
                                <td>{d.name}</td>
                                <td>{d.category_name}</td>
                                <td>{d.material_name}</td>
                                <td>{Number(d.weight_kg).toFixed(3)}</td>
                                <td>{Number(d.price).toFixed(2)}</td>
                                <td>{d.min_stock}</td>
                                <td className="actions">
                                    {canEdit && (
                                        <>
                                            <button className="btn-link" onClick={() => openEdit(d)}>править</button>
                                            <button className="btn-link danger" onClick={() => removeDetail(d.id)}>удалить</button>
                                        </>
                                    )}
                                </td>
                            </tr>
                        ))}
                        {visible.length === 0 && (
                            <tr><td colSpan={8} className="empty">Записей не найдено</td></tr>
                        )}
                    </tbody>
                </table>
            )}

            {modalOpen && (
                <Modal title={editing ? `Редактировать: ${editing.article}` : "Новая деталь"} onClose={closeModal}>
                    <form onSubmit={submitForm} className="form-grid">
                        {formError && <div className="auth-error">{formError}</div>}
                        <div>
                            <label className="form-label">Артикул</label>
                            <input className="form-input" value={form.article} required
                                   onChange={(e) => setForm({ ...form, article: e.target.value })} />
                        </div>
                        <div>
                            <label className="form-label">Наименование</label>
                            <input className="form-input" value={form.name} required
                                   onChange={(e) => setForm({ ...form, name: e.target.value })} />
                        </div>
                        <div>
                            <label className="form-label">Категория</label>
                            <select className="form-input" value={form.category_id} required
                                    onChange={(e) => setForm({ ...form, category_id: e.target.value })}>
                                <option value="">— выберите —</option>
                                {categories.map((c) => (
                                    <option key={c.id} value={c.id}>{c.name}</option>
                                ))}
                            </select>
                        </div>
                        <div>
                            <label className="form-label">Материал</label>
                            <select className="form-input" value={form.material_id} required
                                    onChange={(e) => setForm({ ...form, material_id: e.target.value })}>
                                <option value="">— выберите —</option>
                                {materials.map((m) => (
                                    <option key={m.id} value={m.id}>{m.name} ({m.grade})</option>
                                ))}
                            </select>
                        </div>
                        <div>
                            <label className="form-label">Масса, кг</label>
                            <input className="form-input" type="number" step="0.001" min="0" value={form.weight_kg} required
                                   onChange={(e) => setForm({ ...form, weight_kg: e.target.value })} />
                        </div>
                        <div>
                            <label className="form-label">Цена, ₽</label>
                            <input className="form-input" type="number" step="0.01" min="0" value={form.price} required
                                   onChange={(e) => setForm({ ...form, price: e.target.value })} />
                        </div>
                        <div>
                            <label className="form-label">Чертёж</label>
                            <input className="form-input" value={form.drawing_no}
                                   onChange={(e) => setForm({ ...form, drawing_no: e.target.value })} />
                        </div>
                        <div>
                            <label className="form-label">Минимальный остаток</label>
                            <input className="form-input" type="number" min="0" value={form.min_stock}
                                   onChange={(e) => setForm({ ...form, min_stock: e.target.value })} />
                        </div>
                        <div className="form-actions">
                            <button type="button" className="btn btn-ghost" onClick={closeModal}>Отмена</button>
                            <button type="submit" className="btn btn-primary">{editing ? "Сохранить" : "Создать"}</button>
                        </div>
                    </form>
                </Modal>
            )}
        </section>
    );
}

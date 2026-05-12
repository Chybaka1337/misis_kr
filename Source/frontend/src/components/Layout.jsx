import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

const NAV = [
    { to: "/details",   label: "Каталог деталей" },
    { to: "/stock",     label: "Остатки на складах" },
    { to: "/movements", label: "Движения" },
    { to: "/reports",   label: "Отчёты" },
];

const ROLE_LABELS = {
    admin: "Администратор",
    manager: "Менеджер",
    storekeeper: "Кладовщик",
};

export default function Layout() {
    const { user, logout } = useAuth();

    return (
        <div className="app-shell">
            <aside className="sidebar">
                <h1 className="brand">Деталь</h1>
                <p className="brand-sub">учёт деталей предприятия</p>
                <nav className="nav">
                    {NAV.map((item) => (
                        <NavLink key={item.to} to={item.to} className="nav-link">
                            {item.label}
                        </NavLink>
                    ))}
                </nav>
                <div className="user-block">
                    <div className="user-name">{user?.full_name}</div>
                    <div className="user-role">{ROLE_LABELS[user?.role] || user?.role}</div>
                    <button className="btn-link" onClick={logout}>Выйти</button>
                </div>
            </aside>
            <main className="content">
                <Outlet />
            </main>
        </div>
    );
}

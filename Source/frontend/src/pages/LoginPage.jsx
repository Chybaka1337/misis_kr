import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function LoginPage() {
    const { login } = useAuth();
    const navigate = useNavigate();
    const [loginValue, setLoginValue] = useState("");
    const [password, setPassword] = useState("");
    const [error, setError] = useState("");
    const [submitting, setSubmitting] = useState(false);

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError("");
        setSubmitting(true);
        try {
            await login(loginValue.trim(), password);
            navigate("/details");
        } catch (err) {
            setError(err.message);
        } finally {
            setSubmitting(false);
        }
    };

    return (
        <div className="auth-screen">
            <form className="auth-card" onSubmit={handleSubmit}>
                <h1 className="auth-title">Система учёта деталей</h1>
                <p className="auth-subtitle">Авторизация</p>
                {error && <div className="auth-error">{error}</div>}
                <label className="form-label" htmlFor="login">Логин</label>
                <input id="login" className="form-input"
                       value={loginValue}
                       onChange={(e) => setLoginValue(e.target.value)} required />
                <label className="form-label" htmlFor="password">Пароль</label>
                <input id="password" type="password" className="form-input"
                       value={password}
                       onChange={(e) => setPassword(e.target.value)} required />
                <button type="submit" className="btn btn-primary" disabled={submitting}>
                    {submitting ? "Вход…" : "Войти"}
                </button>
                <p className="auth-hint">
                    Тестовые учётные записи:<br />
                    admin / admin2026 (администратор)<br />
                    manager / manager2026 (менеджер)<br />
                    petrov / ivanov2026 (кладовщик)
                </p>
            </form>
        </div>
    );
}

import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider, useAuth } from "./context/AuthContext";
import Layout from "./components/Layout";
import LoginPage from "./pages/LoginPage";
import DetailsPage from "./pages/DetailsPage";
import StockPage from "./pages/StockPage";
import MovementsPage from "./pages/MovementsPage";
import ReportsPage from "./pages/ReportsPage";
import "./styles.css";

function PrivateLayout() {
    const { user, loading } = useAuth();
    if (loading) return <p className="state-loading">Загрузка…</p>;
    if (!user) return <Navigate to="/login" replace />;
    return <Layout />;
}

function PublicLogin() {
    const { user, loading } = useAuth();
    if (loading) return <p className="state-loading">Загрузка…</p>;
    if (user) return <Navigate to="/details" replace />;
    return <LoginPage />;
}

export default function App() {
    return (
        <BrowserRouter>
            <AuthProvider>
                <Routes>
                    <Route path="/login" element={<PublicLogin />} />
                    <Route element={<PrivateLayout />}>
                        <Route path="/details"   element={<DetailsPage />} />
                        <Route path="/stock"     element={<StockPage />} />
                        <Route path="/movements" element={<MovementsPage />} />
                        <Route path="/reports"   element={<ReportsPage />} />
                    </Route>
                    <Route path="*" element={<Navigate to="/details" replace />} />
                </Routes>
            </AuthProvider>
        </BrowserRouter>
    );
}

<?php

require_once dirname(__DIR__) . '/core/Database.php';
require_once dirname(__DIR__) . '/core/Response.php';
require_once dirname(__DIR__) . '/core/Auth.php';

class ReportController
{
    public function stock(): void
    {
        Auth::require();
        $warehouseId = isset($_GET['warehouse_id']) ? (int)$_GET['warehouse_id'] : null;
        $detailId    = isset($_GET['detail_id']) ? (int)$_GET['detail_id'] : null;

        $sql = "SELECT * FROM v_detail_stock WHERE 1=1";
        $params = [];
        if ($warehouseId !== null) {
            $sql .= " AND warehouse_id = :w";
            $params[':w'] = $warehouseId;
        }
        if ($detailId !== null) {
            $sql .= " AND detail_id = :d";
            $params[':d'] = $detailId;
        }
        $sql .= " ORDER BY article, warehouse_code";
        $stmt = Database::pdo()->prepare($sql);
        $stmt->execute($params);
        Response::ok(['items' => $stmt->fetchAll()]);
    }

    public function lowStock(): void
    {
        Auth::require();
        $stmt = Database::pdo()->query('SELECT * FROM v_low_stock ORDER BY article');
        Response::ok(['items' => $stmt->fetchAll()]);
    }

    public function supplierPurchases(): void
    {
        Auth::require();
        $stmt = Database::pdo()->query('SELECT * FROM v_supplier_purchases ORDER BY total_amount DESC NULLS LAST');
        Response::ok(['items' => $stmt->fetchAll()]);
    }

    public function warehouseValue(): void
    {
        Auth::require();
        $stmt = Database::pdo()->query(
            "SELECT id, code, name, fn_warehouse_value(id) AS total_value FROM warehouse ORDER BY code"
        );
        Response::ok(['items' => $stmt->fetchAll()]);
    }

    public function consumption(): void
    {
        Auth::require();
        $days = isset($_GET['days']) ? max(1, (int)$_GET['days']) : 30;
        $stmt = Database::pdo()->prepare(
            "SELECT d.id, d.article, d.name, fn_detail_consumption(d.id, :days) AS consumed
             FROM detail d
             ORDER BY consumed DESC, d.article"
        );
        $stmt->execute([':days' => $days]);
        Response::ok(['days' => $days, 'items' => $stmt->fetchAll()]);
    }
}

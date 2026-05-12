<?php

require_once dirname(__DIR__) . '/core/Database.php';
require_once dirname(__DIR__) . '/core/Response.php';
require_once dirname(__DIR__) . '/core/Auth.php';

class ReferenceController
{
    public function categories(): void
    {
        Auth::require();
        $stmt = Database::pdo()->query('SELECT id, name, parent_id FROM category ORDER BY COALESCE(parent_id, id), name');
        Response::ok(['items' => $stmt->fetchAll()]);
    }

    public function materials(): void
    {
        Auth::require();
        $stmt = Database::pdo()->query('SELECT id, name, grade, density_kg_m3 FROM material ORDER BY name');
        Response::ok(['items' => $stmt->fetchAll()]);
    }

    public function suppliers(): void
    {
        Auth::require();
        $stmt = Database::pdo()->query('SELECT id, name, inn, phone, email FROM supplier ORDER BY name');
        Response::ok(['items' => $stmt->fetchAll()]);
    }

    public function warehouses(): void
    {
        Auth::require();
        $stmt = Database::pdo()->query('SELECT id, code, name, address FROM warehouse ORDER BY code');
        Response::ok(['items' => $stmt->fetchAll()]);
    }
}

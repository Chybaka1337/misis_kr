<?php

require_once dirname(__DIR__) . '/core/Database.php';

class DetailModel
{
    public function findAll(?string $search = null, ?int $categoryId = null): array
    {
        $sql = "SELECT d.id, d.article, d.name, d.category_id, c.name AS category_name,
                       d.material_id, m.name AS material_name,
                       d.weight_kg, d.unit, d.price, d.drawing_no, d.min_stock,
                       d.created_at, d.updated_at
                FROM detail d
                JOIN category c ON c.id = d.category_id
                JOIN material m ON m.id = d.material_id
                WHERE 1=1";
        $params = [];
        if ($search !== null && $search !== '') {
            $sql .= " AND (d.article ILIKE :search OR d.name ILIKE :search)";
            $params[':search'] = '%' . $search . '%';
        }
        if ($categoryId !== null) {
            $sql .= " AND d.category_id = :cat";
            $params[':cat'] = $categoryId;
        }
        $sql .= " ORDER BY d.article";
        $stmt = Database::pdo()->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll();
    }

    public function findById(int $id): ?array
    {
        $stmt = Database::pdo()->prepare(
            "SELECT d.*, c.name AS category_name, m.name AS material_name
             FROM detail d
             JOIN category c ON c.id = d.category_id
             JOIN material m ON m.id = d.material_id
             WHERE d.id = :id"
        );
        $stmt->execute([':id' => $id]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    public function findByArticle(string $article): ?array
    {
        $stmt = Database::pdo()->prepare('SELECT id FROM detail WHERE article = :a');
        $stmt->execute([':a' => $article]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    public function create(array $data): int
    {
        $stmt = Database::pdo()->prepare(
            "INSERT INTO detail(article, name, category_id, material_id, weight_kg, unit, price, drawing_no, min_stock)
             VALUES (:article, :name, :cat, :mat, :weight, :unit, :price, :drawing, :min)
             RETURNING id"
        );
        $stmt->execute([
            ':article' => $data['article'],
            ':name'    => $data['name'],
            ':cat'     => $data['category_id'],
            ':mat'     => $data['material_id'],
            ':weight'  => $data['weight_kg'],
            ':unit'    => $data['unit'] ?? 'шт',
            ':price'   => $data['price'],
            ':drawing' => $data['drawing_no'] ?? null,
            ':min'     => $data['min_stock'] ?? 0,
        ]);
        return (int)$stmt->fetchColumn();
    }

    public function update(int $id, array $data): bool
    {
        $stmt = Database::pdo()->prepare(
            "UPDATE detail SET
                article = :article, name = :name, category_id = :cat, material_id = :mat,
                weight_kg = :weight, unit = :unit, price = :price,
                drawing_no = :drawing, min_stock = :min
             WHERE id = :id"
        );
        return $stmt->execute([
            ':article' => $data['article'],
            ':name'    => $data['name'],
            ':cat'     => $data['category_id'],
            ':mat'     => $data['material_id'],
            ':weight'  => $data['weight_kg'],
            ':unit'    => $data['unit'] ?? 'шт',
            ':price'   => $data['price'],
            ':drawing' => $data['drawing_no'] ?? null,
            ':min'     => $data['min_stock'] ?? 0,
            ':id'      => $id,
        ]);
    }

    public function delete(int $id): bool
    {
        $stmt = Database::pdo()->prepare('DELETE FROM detail WHERE id = :id');
        return $stmt->execute([':id' => $id]);
    }
}

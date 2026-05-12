<?php

require_once dirname(__DIR__) . '/core/Database.php';
require_once dirname(__DIR__) . '/core/Response.php';
require_once dirname(__DIR__) . '/core/Auth.php';

class MovementController
{
    public function index(): void
    {
        Auth::require();
        $limit = isset($_GET['limit']) ? max(1, min(500, (int)$_GET['limit'])) : 100;
        $stmt = Database::pdo()->prepare(
            "SELECT * FROM v_recent_movements LIMIT :lim"
        );
        $stmt->bindValue(':lim', $limit, PDO::PARAM_INT);
        $stmt->execute();
        Response::ok(['items' => $stmt->fetchAll()]);
    }

    public function receive(): void
    {
        $user = Auth::require();
        $data = $this->jsonBody();
        $this->required($data, ['detail_id', 'warehouse_id', 'supplier_id', 'quantity', 'price_per_unit']);

        try {
            $stmt = Database::pdo()->prepare(
                'CALL sp_receive_detail(:d, :w, :s, :q, :p, :u, :c)'
            );
            $stmt->execute([
                ':d' => (int)$data['detail_id'],
                ':w' => (int)$data['warehouse_id'],
                ':s' => (int)$data['supplier_id'],
                ':q' => (int)$data['quantity'],
                ':p' => (float)$data['price_per_unit'],
                ':u' => (int)$user['id'],
                ':c' => $data['comment'] ?? null,
            ]);
            Response::created(['message' => 'Приход оформлен']);
        } catch (PDOException $e) {
            Response::error(400, $this->normalize($e->getMessage()));
        }
    }

    public function issue(): void
    {
        $user = Auth::require();
        $data = $this->jsonBody();
        $this->required($data, ['detail_id', 'warehouse_id', 'quantity']);

        try {
            $stmt = Database::pdo()->prepare(
                'CALL sp_issue_detail(:d, :w, :q, :u, :c)'
            );
            $stmt->execute([
                ':d' => (int)$data['detail_id'],
                ':w' => (int)$data['warehouse_id'],
                ':q' => (int)$data['quantity'],
                ':u' => (int)$user['id'],
                ':c' => $data['comment'] ?? null,
            ]);
            Response::created(['message' => 'Списание оформлено']);
        } catch (PDOException $e) {
            Response::error(400, $this->normalize($e->getMessage()));
        }
    }

    public function transfer(): void
    {
        $user = Auth::require();
        $data = $this->jsonBody();
        $this->required($data, ['detail_id', 'warehouse_from', 'warehouse_to', 'quantity']);

        try {
            $stmt = Database::pdo()->prepare(
                'CALL sp_transfer_detail(:d, :f, :t, :q, :u)'
            );
            $stmt->execute([
                ':d' => (int)$data['detail_id'],
                ':f' => (int)$data['warehouse_from'],
                ':t' => (int)$data['warehouse_to'],
                ':q' => (int)$data['quantity'],
                ':u' => (int)$user['id'],
            ]);
            Response::created(['message' => 'Перемещение выполнено']);
        } catch (PDOException $e) {
            Response::error(400, $this->normalize($e->getMessage()));
        }
    }

    public function destroy(array $params): void
    {
        Auth::requireRole(['admin']);
        $id = (int)$params['id'];
        $stmt = Database::pdo()->prepare('DELETE FROM stock_movement WHERE id = :id');
        $stmt->execute([':id' => $id]);
        if ($stmt->rowCount() === 0) {
            Response::error(404, 'Движение не найдено');
        }
        Response::ok(['id' => $id]);
    }

    private function required(array $data, array $fields): void
    {
        foreach ($fields as $f) {
            if (!isset($data[$f]) || $data[$f] === '') {
                Response::error(400, "Поле $f обязательно");
            }
        }
        if (isset($data['quantity']) && (int)$data['quantity'] <= 0) {
            Response::error(400, 'Количество должно быть положительным');
        }
    }

    private function normalize(string $message): string
    {
        if (preg_match('/ERROR:\s*(.+?)(?:CONTEXT|$)/s', $message, $m)) {
            return trim($m[1]);
        }
        return $message;
    }

    private function jsonBody(): array
    {
        $raw = file_get_contents('php://input') ?: '';
        $data = json_decode($raw, true);
        return is_array($data) ? $data : [];
    }
}

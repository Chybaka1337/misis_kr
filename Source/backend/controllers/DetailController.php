<?php

require_once dirname(__DIR__) . '/core/Response.php';
require_once dirname(__DIR__) . '/core/Auth.php';
require_once dirname(__DIR__) . '/models/DetailModel.php';

class DetailController
{
    private DetailModel $details;

    public function __construct()
    {
        $this->details = new DetailModel();
    }

    public function index(): void
    {
        Auth::require();
        $search = $_GET['q'] ?? null;
        $categoryId = isset($_GET['category_id']) ? (int)$_GET['category_id'] : null;
        Response::ok(['items' => $this->details->findAll($search, $categoryId)]);
    }

    public function show(array $params): void
    {
        Auth::require();
        $detail = $this->details->findById((int)$params['id']);
        if ($detail === null) {
            Response::error(404, 'Деталь не найдена');
        }
        Response::ok($detail);
    }

    public function store(): void
    {
        Auth::requireRole(['admin', 'manager']);
        $data = $this->jsonBody();
        $this->validate($data);

        try {
            $id = $this->details->create($data);
            Response::created($this->details->findById($id));
        } catch (PDOException $e) {
            if ($e->getCode() === '23505') {
                Response::error(409, 'Деталь с таким артикулом уже существует');
            }
            Response::error(400, $e->getMessage());
        }
    }

    public function update(array $params): void
    {
        Auth::requireRole(['admin', 'manager']);
        $id = (int)$params['id'];
        if ($this->details->findById($id) === null) {
            Response::error(404, 'Деталь не найдена');
        }
        $data = $this->jsonBody();
        $this->validate($data);

        try {
            $this->details->update($id, $data);
            Response::ok($this->details->findById($id));
        } catch (PDOException $e) {
            if ($e->getCode() === '23505') {
                Response::error(409, 'Артикул уже используется другой деталью');
            }
            Response::error(400, $e->getMessage());
        }
    }

    public function destroy(array $params): void
    {
        Auth::requireRole(['admin', 'manager']);
        $id = (int)$params['id'];
        if ($this->details->findById($id) === null) {
            Response::error(404, 'Деталь не найдена');
        }
        try {
            $this->details->delete($id);
            Response::ok(['id' => $id]);
        } catch (PDOException $e) {
            if ($e->getCode() === '23503') {
                Response::error(409, 'Невозможно удалить: по детали есть движения на складе');
            }
            Response::error(400, $e->getMessage());
        }
    }

    private function validate(array $data): void
    {
        $required = ['article', 'name', 'category_id', 'material_id', 'weight_kg', 'price'];
        foreach ($required as $field) {
            if (!isset($data[$field]) || $data[$field] === '') {
                Response::error(400, "Поле $field обязательно");
            }
        }
        if ((float)$data['weight_kg'] < 0) {
            Response::error(400, 'Масса не может быть отрицательной');
        }
        if ((float)$data['price'] < 0) {
            Response::error(400, 'Цена не может быть отрицательной');
        }
    }

    private function jsonBody(): array
    {
        $raw = file_get_contents('php://input') ?: '';
        $data = json_decode($raw, true);
        return is_array($data) ? $data : [];
    }
}

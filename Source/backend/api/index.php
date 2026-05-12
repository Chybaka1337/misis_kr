<?php

declare(strict_types=1);

require_once dirname(__DIR__) . '/core/Router.php';
require_once dirname(__DIR__) . '/core/Response.php';

$config = require dirname(__DIR__) . '/config.php';

header('Access-Control-Allow-Origin: ' . $config['cors']['origin']);
header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Max-Age: 3600');

if (($_SERVER['REQUEST_METHOD'] ?? 'GET') === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$router = new Router();
require dirname(__DIR__) . '/api/routes.php';

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$uri    = $_SERVER['REQUEST_URI'] ?? '/';

set_exception_handler(function (Throwable $e): void {
    Response::error(500, 'Внутренняя ошибка сервера: ' . $e->getMessage());
});

if (!$router->dispatch($method, $uri)) {
    Response::error(404, 'Маршрут не найден', [
        'method' => $method,
        'path'   => parse_url($uri, PHP_URL_PATH),
    ]);
}

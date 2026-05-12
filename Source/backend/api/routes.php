<?php

require_once dirname(__DIR__) . '/controllers/AuthController.php';
require_once dirname(__DIR__) . '/controllers/DetailController.php';
require_once dirname(__DIR__) . '/controllers/MovementController.php';
require_once dirname(__DIR__) . '/controllers/ReferenceController.php';
require_once dirname(__DIR__) . '/controllers/ReportController.php';

/** @var Router $router */

$auth = new AuthController();
$details = new DetailController();
$movements = new MovementController();
$refs = new ReferenceController();
$reports = new ReportController();

$router->post('/api/v1/auth/login', fn($p) => $auth->login());
$router->get ('/api/v1/auth/me',    fn($p) => $auth->me());

$router->get   ('/api/v1/details',        fn($p) => $details->index());
$router->get   ('/api/v1/details/{id}',   fn($p) => $details->show($p));
$router->post  ('/api/v1/details',        fn($p) => $details->store());
$router->put   ('/api/v1/details/{id}',   fn($p) => $details->update($p));
$router->delete('/api/v1/details/{id}',   fn($p) => $details->destroy($p));

$router->get   ('/api/v1/movements',           fn($p) => $movements->index());
$router->post  ('/api/v1/movements/receive',   fn($p) => $movements->receive());
$router->post  ('/api/v1/movements/issue',     fn($p) => $movements->issue());
$router->post  ('/api/v1/movements/transfer',  fn($p) => $movements->transfer());
$router->delete('/api/v1/movements/{id}',      fn($p) => $movements->destroy($p));

$router->get('/api/v1/categories', fn($p) => $refs->categories());
$router->get('/api/v1/materials',  fn($p) => $refs->materials());
$router->get('/api/v1/suppliers',  fn($p) => $refs->suppliers());
$router->get('/api/v1/warehouses', fn($p) => $refs->warehouses());

$router->get('/api/v1/reports/stock',            fn($p) => $reports->stock());
$router->get('/api/v1/reports/low-stock',        fn($p) => $reports->lowStock());
$router->get('/api/v1/reports/suppliers',        fn($p) => $reports->supplierPurchases());
$router->get('/api/v1/reports/warehouse-value',  fn($p) => $reports->warehouseValue());
$router->get('/api/v1/reports/consumption',      fn($p) => $reports->consumption());

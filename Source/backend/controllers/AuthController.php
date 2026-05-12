<?php

require_once dirname(__DIR__) . '/core/Database.php';
require_once dirname(__DIR__) . '/core/Response.php';
require_once dirname(__DIR__) . '/core/Jwt.php';
require_once dirname(__DIR__) . '/core/Auth.php';

class AuthController
{
    public function login(): void
    {
        $body = $this->jsonBody();
        $login = trim((string)($body['login'] ?? ''));
        $password = (string)($body['password'] ?? '');

        if ($login === '' || $password === '') {
            Response::error(400, 'Поля login и password обязательны');
        }

        $stmt = Database::pdo()->prepare('SELECT id, login, full_name, email, password_hash, role FROM users WHERE login = :login');
        $stmt->execute([':login' => $login]);
        $user = $stmt->fetch();
        if (!$user || !password_verify($password, $user['password_hash'])) {
            Response::error(401, 'Неверный логин или пароль');
        }

        $config = require dirname(__DIR__) . '/config.php';
        $token = Jwt::encode([
            'sub'   => (int)$user['id'],
            'login' => $user['login'],
            'role'  => $user['role'],
        ], $config['jwt']['secret'], $config['jwt']['ttl_minutes']);

        unset($user['password_hash']);
        Response::ok(['token' => $token, 'user' => $user]);
    }

    public function me(): void
    {
        $user = Auth::require();
        Response::ok(['user' => $user]);
    }

    private function jsonBody(): array
    {
        $raw = file_get_contents('php://input') ?: '';
        $data = json_decode($raw, true);
        return is_array($data) ? $data : [];
    }
}

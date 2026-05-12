<?php

require_once __DIR__ . '/Jwt.php';
require_once __DIR__ . '/Database.php';
require_once __DIR__ . '/Response.php';

class Auth
{
    public static function currentUser(): ?array
    {
        $token = self::extractToken();
        if ($token === null) {
            return null;
        }
        $config = require dirname(__DIR__) . '/config.php';
        $payload = Jwt::decode($token, $config['jwt']['secret']);
        if ($payload === null || empty($payload['sub'])) {
            return null;
        }
        $stmt = Database::pdo()->prepare('SELECT id, login, full_name, email, role FROM users WHERE id = :id');
        $stmt->execute([':id' => $payload['sub']]);
        $user = $stmt->fetch();
        return $user ?: null;
    }

    public static function require(): array
    {
        $user = self::currentUser();
        if ($user === null) {
            Response::error(401, 'Требуется авторизация');
        }
        return $user;
    }

    public static function requireRole(array $allowed): array
    {
        $user = self::require();
        if (!in_array($user['role'], $allowed, true)) {
            Response::error(403, 'Недостаточно прав');
        }
        return $user;
    }

    private static function extractToken(): ?string
    {
        $headers = self::headers();
        $auth = $headers['authorization'] ?? $headers['Authorization'] ?? '';
        if (stripos($auth, 'Bearer ') === 0) {
            return trim(substr($auth, 7));
        }
        return null;
    }

    private static function headers(): array
    {
        if (function_exists('getallheaders')) {
            $h = getallheaders();
            return array_change_key_case($h, CASE_LOWER);
        }
        $out = [];
        foreach ($_SERVER as $k => $v) {
            if (strncmp($k, 'HTTP_', 5) === 0) {
                $name = strtolower(str_replace('_', '-', substr($k, 5)));
                $out[$name] = $v;
            }
        }
        return $out;
    }
}

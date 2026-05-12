<?php

class Response
{
    public static function json(int $status, array $payload): void
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
        exit;
    }

    public static function ok(array $data): void
    {
        self::json(200, ['status' => 'success', 'data' => $data]);
    }

    public static function created(array $data): void
    {
        self::json(201, ['status' => 'success', 'data' => $data]);
    }

    public static function error(int $status, string $message, array $extra = []): void
    {
        self::json($status, array_merge(['status' => 'error', 'message' => $message], $extra));
    }
}

<?php

class Router
{
    private array $routes = [];

    public function add(string $method, string $path, callable $handler): void
    {
        $this->routes[] = [
            'method'  => strtoupper($method),
            'pattern' => $this->compilePattern($path),
            'handler' => $handler,
        ];
    }

    public function get(string $path, callable $handler): void    { $this->add('GET',    $path, $handler); }
    public function post(string $path, callable $handler): void   { $this->add('POST',   $path, $handler); }
    public function put(string $path, callable $handler): void    { $this->add('PUT',    $path, $handler); }
    public function patch(string $path, callable $handler): void  { $this->add('PATCH',  $path, $handler); }
    public function delete(string $path, callable $handler): void { $this->add('DELETE', $path, $handler); }

    public function dispatch(string $method, string $uri): bool
    {
        $method = strtoupper($method);
        $path = parse_url($uri, PHP_URL_PATH) ?? '/';

        foreach ($this->routes as $route) {
            if ($route['method'] !== $method) {
                continue;
            }
            if (preg_match($route['pattern'], $path, $matches)) {
                $params = array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);
                ($route['handler'])($params);
                return true;
            }
        }
        return false;
    }

    private function compilePattern(string $path): string
    {
        $regex = preg_replace('#\{(\w+)\}#', '(?P<$1>[^/]+)', $path);
        return '#^' . $regex . '$#';
    }
}

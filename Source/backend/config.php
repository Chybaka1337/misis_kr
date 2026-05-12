<?php
return [
    'db' => [
        'host'     => '127.0.0.1',
        'port'     => 5433,
        'name'     => 'misis_kr_detail',
        'user'     => 'postgres',
        'password' => 'kursovaya2026',
    ],
    'jwt' => [
        'secret'      => 'misis-kr-detal-2026-secret-key-please-change-in-production',
        'algorithm'   => 'HS256',
        'ttl_minutes' => 720,
    ],
    'cors' => [
        'origin' => '*',
    ],
];

<?php

require_once '/checks/bootstrap.php';

use Illuminate\Support\Facades\Redis;

try {
    Redis::ping();
    exit(0);
} catch (Exception $e) {
    echo 'Redis connection error: ' . $e->getMessage();
    exit(1);
}

<?php

require '/laravel/vendor/autoload.php';

use Illuminate\Cache\CacheManager;

$app = require_once '/laravel/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

try {
  $store = app(CacheManager::class)->store();
  $testKey = 'connection_test_' . time();

  $store->put($testKey, 'test_value', 1);

  if ($store->get($testKey) === 'test_value') {
    $store->forget($testKey);
    exit(0);
  }

  echo 'Cache store is not working properly: Test value mismatch.';
  exit(1);
} catch (Exception $e) {
  echo 'Cache connection error: ' . $e->getMessage();
  exit(1);
}

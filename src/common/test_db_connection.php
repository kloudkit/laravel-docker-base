<?php

require '/laravel/vendor/autoload.php';

use Illuminate\Support\Facades\DB;

$app = require_once '/laravel/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

try {
  DB::connection()->getPdo();

  if (DB::connection()->getDatabaseName()) {
    exit(0);
  }

  echo 'Database name not found.';
  exit(1);

} catch (Exception $e) {
  echo 'Database connection error: ' . $e->getMessage();
  exit(1);
}

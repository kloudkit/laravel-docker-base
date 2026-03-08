<?php

require_once '/checks/bootstrap.php';

use Illuminate\Support\Facades\DB;

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

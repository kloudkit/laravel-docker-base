<?php

require '/laravel/vendor/autoload.php';

$app = require_once '/laravel/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

<?php

require '/laravel/vendor/autoload.php';

use Illuminate\Support\Facades\Storage;

$app = require_once '/laravel/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

try {
    $disk = Storage::disk('s3');

    $testFileName = 's3_connection_test_' . time() . '.txt';

    $disk->put($testFileName, 's3_test_value');

    if ('s3_test_value' === $disk->get($testFileName)) {
        $disk->delete($testFileName);
        exit(0);
    }

    echo 'S3 store is not working properly: Test value mismatch.';
    exit(1);

} catch (Exception $e) {
    echo 'S3 connection error: ' . $e->getMessage();
    exit(1);
}

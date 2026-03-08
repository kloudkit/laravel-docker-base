<?php

require_once '/checks/bootstrap.php';

use Illuminate\Support\Facades\Storage;

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

<?php

require_once '/checks/bootstrap.php';

use Illuminate\Support\Facades\Queue;

try {
    Queue::size();
    exit(0);
} catch (Exception $e) {
    echo 'Queue connection error: ' . $e->getMessage();
    exit(1);
}

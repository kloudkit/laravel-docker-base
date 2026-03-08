<?php

require_once '/checks/bootstrap.php';

$warnings = [];

$session = config('session.driver');
if (in_array($session, ['file', 'array'], true)) {
    $warnings[] = "Session driver is [$session]"
        . "\n\tUse [redis] or [database] for multi-container deployments.";
}

$store = config('cache.default');
$driver = config("cache.stores.$store.driver");
if (in_array($driver, ['file', 'array'], true)) {
    $warnings[] = "Cache store [$store] uses driver [$driver]"
        . "\n\tUse [redis] or [memcached] for multi-container deployments.";
}

$queue = config('queue.default');
$driver = config("queue.connections.$queue.driver");
if ($driver === 'sync') {
    $warnings[] = "Queue connection [$queue] uses driver [sync]"
        . "\n\tUse [redis], [sqs], or [database] for multi-container deployments.";
}

$logging = config('logging.default');
$driver = config("logging.channels.$logging.driver");
if (in_array($driver, ['single', 'daily'], true)) {
    $warnings[] = "Log channel [$logging] uses driver [$driver]"
        . "\n\tUse [stderr] for containerized deployments.";
}

$broadcast = config('broadcasting.default');
$driver = config("broadcasting.connections.$broadcast.driver") ?? $broadcast;
if (in_array($driver, ['log', 'null'], true)) {
    $path = base_path('routes/channels.php');
    if (file_exists($path) && str_contains(file_get_contents($path), 'Broadcast::')) {
        $warnings[] = "Broadcast driver is [$driver] but channels.php uses Broadcast::"
            . "\n \tUse [reverb], [pusher], or [ably].";
    }
}

foreach ($warnings as $warning) {
    echo $warning . "\n";
}

exit(0);

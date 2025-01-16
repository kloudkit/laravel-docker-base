<?php

require 'vendor/autoload.php';

use Symfony\Component\Mailer\Transport;
use Symfony\Component\Mailer\Mailer;

$app = require_once 'bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

try {
    $dsn = sprintf(
        'smtp://%s:%s@%s:%d',
        config('mail.mailers.smtp.username'),
        config('mail.mailers.smtp.password'),
        config('mail.mailers.smtp.host'),
        config('mail.mailers.smtp.port')
    );

    if (config('mail.mailers.smtp.encryption') === 'tls') {
        $dsn .= '?encryption=tls';
    }

    $transport = Transport::fromDsn($dsn);
    $mailer = new Mailer($transport);

    $transport->start();

    exit(0);
} catch (Exception $e) {
    echo 'SMTP connection error: ' . $e->getMessage();
    exit(1);
}

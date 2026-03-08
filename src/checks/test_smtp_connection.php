<?php

require_once '/checks/bootstrap.php';

use Symfony\Component\Mailer\Transport;
use Symfony\Component\Mailer\Mailer;

try {
    $scheme = config('mail.mailers.smtp.encryption') === 'tls' ? 'smtps' : 'smtp';

    $dsn = sprintf(
        '%s://%s:%s@%s:%d',
        $scheme,
        urlencode(config('mail.mailers.smtp.username') ?? ''),
        urlencode(config('mail.mailers.smtp.password') ?? ''),
        config('mail.mailers.smtp.host'),
        config('mail.mailers.smtp.port')
    );

    $transport = Transport::fromDsn($dsn);
    $mailer = new Mailer($transport);

    $transport->start();

    exit(0);
} catch (Exception $e) {
    echo 'SMTP connection error: ' . $e->getMessage();
    exit(1);
}

<?php
declare(strict_types=1);
require __DIR__ . '/vendor/autoload.php';
use FastVolt\Helper\Markdown;
// ----------------------------------
// Configuration
// ----------------------------------
$readmePath = '/var/www/project/README.md';

if (!file_exists($readmePath)) {
    http_response_code(404);
    echo "README.md not found.";
    exit;
}
$markdown = new Markdown(); // or Markdown::new()
$text = file_get_contents($readmePath);
$markdown->setContent($text);


$host = $_SERVER['HTTP_HOST'];
$host = explode(':', $host)[0];
$parts = explode('.', $host);
if (count($parts) >= 2) {
    $rootDomain = $parts[count($parts) - 2] . '.' . $parts[count($parts) - 1];
} else {
    $rootDomain = $host;
}

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Project README</title>
    <style>

        html, body {
            margin: 0;
            font-family: system-ui;
        }

        /* hauteur du footer */
        :root {
            --footer-height: 56px;
        }

        header p {
            max-width: 900px;
            margin: 0 auto;
        }

        header img {
            display: block;
            margin: 40px 0;
        }

        /* contenu */
        .content {
            max-width: 900px;
            margin: 0 auto;
            padding: 0 20px calc(var(--footer-height) + 20px);
        }

        /* footer FIXED */
        .footer {
            position: fixed;
            bottom: 0;
            left: 0;
            right: 0;

            height: var(--footer-height);
            display: flex;
            align-items: center;
            justify-content: center;

            background: #fafafa;
            border-top: 1px solid #eaeaea;
            font-size: 0.85rem;
            color: #666;
            z-index: 1000;
        }

    </style>
</head>
<body>

<div class="page">

    <header>
        <p><img src="/od-logo.png" width="291" /> </p>
    </header>

    <main class="content">
        <div class="content-inner">
        <?= $markdown->getHtml(); ?>
        </div>
    </main>

    <footer class="footer">
        <p>Online documentation : <a href="https://github.com/itakademy/AkaStack/wiki" target="_blank">AkaStack Wiki on Github</a>
            Endpoints :
            <a href="https://www.<?= $rootDomain ?>" target="_blank">Front-end</a> |
            <a href="https://back.<?= $rootDomain ?>" target="_blank">Back-end</a> |
            <a href="https://back.<?= $rootDomain ?>/admin" target="_blank">Back-end admin</a> |
            <a href="https://back.<?= $rootDomain ?>/api" target="_blank">Api Platform</a> |
            <a href="https://back.<?= $rootDomain ?>/horizon" target="_blank">Horizon</a> |
            <a href="https://swagger.<?= $rootDomain ?>" target="_blank">Swagger</a> |
            <a href="/phpmyadmin" target="_blank">PhpMyAdmin</a> |
            <a href="/phpinfo" target="_blank">PhpInfo()</a> |
            <a href="https://mongo.<?= $rootDomain ?>" target="_blank">Mongo Express</a> |
            <a href="https://mail.<?= $rootDomain ?>" target="_blank">MailHog</a> |
            <a href="https://redis.<?= $rootDomain ?>" target="_blank">Redis Commander</a>
        <small>
            © <?= date('Y') ?> Orizon Digital
        </small>
        </p>
    </footer>

</div>

</body>
</html>

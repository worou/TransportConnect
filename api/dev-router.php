<?php

// Routeur pour le serveur PHP intégré (développement) :
//   php -S 127.0.0.1:8000 -t public dev-router.php
// Sert directement les fichiers statiques (Swagger UI), sinon délègue à Symfony.

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if ('/' !== $path && is_file(__DIR__.'/public'.$path)) {
    return false;
}

$_SERVER['SCRIPT_FILENAME'] = __DIR__.'/public/index.php';
require __DIR__.'/public/index.php';

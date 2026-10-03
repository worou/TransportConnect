<?php

// Contrôleur frontal de l'API, placé à la racine du sous-domaine.
// Le projet Symfony est installé hors de la racine web (~/transco_app) : seul ce fichier est exposé.

use App\Kernel;

require_once dirname(__DIR__).'/transco_app/vendor/autoload_runtime.php';

return function (array $context) {
    return new Kernel($context['APP_ENV'], (bool) $context['APP_DEBUG']);
};

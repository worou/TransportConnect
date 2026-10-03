<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.contexte_photo */
enum ContextePhoto: string
{
    case Demande = 'demande';
    case Evaluation = 'evaluation';
    case Livraison = 'livraison';
}

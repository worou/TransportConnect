<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.motif_litige */
enum MotifLitige: string
{
    case ColisEndommage = 'colis_endommage';
    case ColisManquant = 'colis_manquant';
    case NonLivre = 'non_livre';
    case Autre = 'autre';
}

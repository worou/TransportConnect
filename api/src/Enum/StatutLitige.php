<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.statut_litige */
enum StatutLitige: string
{
    case Ouvert = 'ouvert';
    case EnCours = 'en_cours';
    case Resolu = 'resolu';
}

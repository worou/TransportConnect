<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.statut_verification */
enum StatutVerification: string
{
    case EnAttente = 'en_attente';
    case Valide = 'valide';
    case Rejete = 'rejete';
}

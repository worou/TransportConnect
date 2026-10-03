<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.statut_compte */
enum StatutCompte: string
{
    case EnAttenteValidation = 'en_attente_validation';
    case Actif = 'actif';
    case Suspendu = 'suspendu';
}

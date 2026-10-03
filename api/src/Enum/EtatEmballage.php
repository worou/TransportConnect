<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.etat_emballage */
enum EtatEmballage: string
{
    case Bon = 'bon';
    case Moyen = 'moyen';
    case Mauvais = 'mauvais';
}

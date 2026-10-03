<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.statut_paiement */
enum StatutPaiement: string
{
    case Initie = 'initie';
    case EnCours = 'en_cours';
    case Reussi = 'reussi';
    case Echoue = 'echoue';
    case Rembourse = 'rembourse';
}

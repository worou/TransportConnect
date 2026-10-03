<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.moyen_paiement */
enum MoyenPaiement: string
{
    case MobileMoney = 'mobile_money';
    case Carte = 'carte';
    case Virement = 'virement';
}

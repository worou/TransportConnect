<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.emetteur_message */
enum EmetteurMessage: string
{
    case Marchand = 'marchand';
    case Representant = 'representant';
}

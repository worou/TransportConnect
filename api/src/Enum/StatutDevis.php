<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.statut_devis */
enum StatutDevis: string
{
    case Propose = 'propose';
    case EnNegociation = 'en_negociation';
    case Accepte = 'accepte';
    case Refuse = 'refuse';
    case Expire = 'expire';
}

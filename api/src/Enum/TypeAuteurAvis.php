<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.type_auteur_avis */
enum TypeAuteurAvis: string
{
    case Marchand = 'marchand';
    case Transporteur = 'transporteur';
}

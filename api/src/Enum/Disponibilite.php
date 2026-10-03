<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.disponibilite */
enum Disponibilite: string
{
    case Disponible = 'disponible';
    case Occupe = 'occupe';
    case HorsLigne = 'hors_ligne';
}

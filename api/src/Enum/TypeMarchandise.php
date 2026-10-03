<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.type_marchandise */
enum TypeMarchandise: string
{
    case Standard = 'standard';
    case Alimentaire = 'alimentaire';
    case Fragile = 'fragile';
    case Dangereuse = 'dangereuse';
    case Betail = 'betail';
}

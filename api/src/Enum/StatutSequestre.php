<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.statut_sequestre */
enum StatutSequestre: string
{
    case Bloque = 'bloque';
    case Libere = 'libere';
    case RembourseTotal = 'rembourse_total';
    case RemboursePartiel = 'rembourse_partiel';
}

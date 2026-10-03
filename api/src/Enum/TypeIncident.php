<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.type_incident */
enum TypeIncident: string
{
    case Panne = 'panne';
    case Accident = 'accident';
    case Retard = 'retard';
    case Autre = 'autre';
}

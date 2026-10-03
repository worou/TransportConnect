<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.niveau_urgence */
enum NiveauUrgence: string
{
    case Normale = 'normale';
    case Express = 'express';
}

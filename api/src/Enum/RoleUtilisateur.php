<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.role_utilisateur */
enum RoleUtilisateur: string
{
    case Marchand = 'marchand';
    case Representant = 'representant';
    case Chauffeur = 'chauffeur';
    case Admin = 'admin';
}

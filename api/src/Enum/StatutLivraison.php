<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.statut_livraison */
enum StatutLivraison: string
{
    case PretEnlevement = 'pret_enlevement';
    case Enleve = 'enleve';
    case EnTransit = 'en_transit';
    case Incident = 'incident';
    case Arrive = 'arrive';
    case Livre = 'livre';
}

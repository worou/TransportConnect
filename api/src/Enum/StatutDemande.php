<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.statut_demande */
enum StatutDemande: string
{
    case EnAttente = 'EN_ATTENTE';
    case RepresentantAssigne = 'REPRESENTANT_ASSIGNE';
    case EnEvaluation = 'EN_EVALUATION';
    case PrixPropose = 'PRIX_PROPOSE';
    case EnNegociation = 'EN_NEGOCIATION';
    case PaiementEnAttente = 'PAIEMENT_EN_ATTENTE';
    case Paye = 'PAYE';
    case EnTransit = 'EN_TRANSIT';
    case Livre = 'LIVRE';
    case Annule = 'ANNULE';
    case Litige = 'LITIGE';
}

<?php

namespace App\Enum;

/** Type PostgreSQL transconnect.decision_litige */
enum DecisionLitige: string
{
    case RemboursementTotal = 'remboursement_total';
    case RemboursementPartiel = 'remboursement_partiel';
    case LiberationTransporteur = 'liberation_transporteur';
}

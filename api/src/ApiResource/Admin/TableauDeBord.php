<?php

namespace App\ApiResource\Admin;

use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\QueryParameter;
use ApiPlatform\OpenApi\Model\Operation;
use App\State\Admin\TableauDeBordProvider;

/** Indicateurs du back-office sur une période (7, 30 ou 365 jours), comparés à la période précédente. */
#[ApiResource(
    operations: [
        new Get(
            uriTemplate: '/admin/tableau-de-bord',
            uriVariables: [],
            provider: TableauDeBordProvider::class,
            security: "is_granted('ROLE_ADMIN')",
            parameters: [
                'periode' => new QueryParameter(
                    schema: ['type' => 'string', 'enum' => ['7', '30', '365'], 'default' => '30'],
                    description: 'Période en jours',
                ),
            ],
            openapi: new Operation(tags: ['Back-office'], summary: 'Indicateurs du tableau de bord admin'),
        ),
    ],
)]
final class TableauDeBord
{
    public int $periode = 30;

    public int $demandes = 0;
    /** Évolution en % par rapport à la période précédente (null si pas de référence) */
    public ?float $demandesEvolutionPct = null;
    public int $transporteursActifs = 0;
    public int $transporteursNouveaux = 0;
    public int $marchandsInscrits = 0;
    public int $marchandsNouveaux = 0;
    /** FCFA */
    public int $chiffreAffaires = 0;
    public ?float $chiffreAffairesEvolutionPct = null;
    /** FCFA */
    public int $commissions = 0;
    /** Devis émis sur la période et payés */
    public ?float $tauxConversionPct = null;
    /** Entre la création de la demande et la soumission de l'évaluation */
    public ?int $delaiMoyenEvaluationMinutes = null;
    public ?float $tauxLitigePct = null;
    public int $litigesOuverts = 0;
    public int $kycEnAttente = 0;
    public int $comptesEnAttente = 0;
    public int $transporteursEnAttente = 0;
    public int $villesCouvertes = 0;
    public float $tauxCommissionPct = 0;
    /** @var list<array{ville: string, nb_demandes: int}> */
    public array $zonesActives = [];
    /** @var array<string, int> statut => nombre */
    public array $demandesParStatut = [];
    /** @var list<array{jour: string, nb_demandes: int}> 14 derniers jours */
    public array $demandesParJour = [];
}

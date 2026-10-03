<?php

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\ExactFilter;
use ApiPlatform\Doctrine\Orm\Filter\PartialSearchFilter;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\QueryParameter;
use App\Enum\NiveauUrgence;
use App\Enum\StatutDemande;
use App\Enum\StatutDevis;
use App\Enum\StatutLivraison;
use App\Enum\StatutPaiement;
use App\Enum\StatutSequestre;
use App\Enum\TypeMarchandise;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;

/**
 * Vue v_suivi_demande (lecture seule) : une ligne par demande avec villes, acteurs,
 * dernier devis, paiement et livraison. Alimente les tableaux du back-office.
 */
#[ORM\Entity(readOnly: true)]
#[ORM\Table(name: 'v_suivi_demande', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: [
            'statut' => new QueryParameter(filter: new ExactFilter(), property: 'statut'),
            'numero' => new QueryParameter(filter: new PartialSearchFilter(), property: 'numero'),
            'marchand' => new QueryParameter(filter: new PartialSearchFilter(), property: 'marchand'),
        ]),
        new Get(),
    ],
    security: "is_granted('ROLE_ADMIN')",
    order: ['createdAt' => 'DESC'],
)]
class SuiviDemande
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_demande', type: UuidType::NAME)]
    public Uuid $id;

    #[ORM\Column]
    public string $numero;

    #[ORM\Column(type: 'string', enumType: StatutDemande::class)]
    public StatutDemande $statut;

    #[ORM\Column]
    public string $villeDepart;

    #[ORM\Column]
    public string $villeArrivee;

    #[ORM\Column(type: 'string', enumType: TypeMarchandise::class)]
    public TypeMarchandise $typeMarchandise;

    #[ORM\Column(type: 'decimal', nullable: true)]
    public ?string $poidsEstime = null;

    #[ORM\Column(type: 'string', enumType: NiveauUrgence::class)]
    public NiveauUrgence $urgence;

    #[ORM\Column(type: 'date_immutable')]
    public \DateTimeImmutable $dateEnlevement;

    #[ORM\Column(nullable: true)]
    public ?string $marchand = null;

    #[ORM\Column(nullable: true)]
    public ?string $representant = null;

    #[ORM\Column(nullable: true)]
    public ?string $transporteur = null;

    #[ORM\Column(nullable: true)]
    public ?int $prixPropose = null;

    #[ORM\Column(type: 'smallint', nullable: true)]
    public ?int $delaiJours = null;

    #[ORM\Column(type: 'string', nullable: true, enumType: StatutDevis::class)]
    public ?StatutDevis $statutDevis = null;

    #[ORM\Column(type: 'string', nullable: true, enumType: StatutPaiement::class)]
    public ?StatutPaiement $statutPaiement = null;

    #[ORM\Column(type: 'string', nullable: true, enumType: StatutSequestre::class)]
    public ?StatutSequestre $statutSequestre = null;

    #[ORM\Column(type: 'string', nullable: true, enumType: StatutLivraison::class)]
    public ?StatutLivraison $statutLivraison = null;

    #[ORM\Column(type: 'date_immutable', nullable: true)]
    public ?\DateTimeImmutable $dateArriveeEstimee = null;

    #[ORM\Column(type: 'datetimetz_immutable')]
    public \DateTimeImmutable $createdAt;
}

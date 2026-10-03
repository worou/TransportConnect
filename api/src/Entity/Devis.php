<?php

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\ExactFilter;
use ApiPlatform\Doctrine\Orm\Filter\IriFilter;
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Patch;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\QueryParameter;
use App\Enum\StatutDevis;
use App\State\DevisProcessor;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * Devis émis après évaluation. Le prix suggéré est calculé par la grille tarifaire à la création ;
 * le prix proposé peut s'en écarter de ±20 % avec justification.
 */
#[ORM\Entity]
#[ORM\Table(name: 'devis', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: [
            'evaluation' => new QueryParameter(filter: new IriFilter(), property: 'evaluation'),
            'statut' => new QueryParameter(filter: new ExactFilter(), property: 'statut'),
        ]),
        new Get(),
        new Post(processor: DevisProcessor::class,
                 securityPostDenormalize: "is_granted('ROLE_ADMIN') or object.evaluation.representant == user"),
        new Patch(processor: DevisProcessor::class,
                  security: "is_granted('ROLE_ADMIN') or object.evaluation.representant == user or object.evaluation.demande.marchand == user"),
    ],
)]
class Devis
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_devis', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\OneToOne]
    #[ORM\JoinColumn(name: 'id_evaluation', referencedColumnName: 'id_evaluation', nullable: false, onDelete: 'CASCADE')]
    #[Assert\NotNull]
    public Evaluation $evaluation;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_grille', referencedColumnName: 'id_grille', nullable: false)]
    #[Assert\NotNull]
    public GrilleTarifaire $grille;

    /** Calculé : (base + distance × tarif_km + poids réel × tarif_kg) × coef type + express */
    #[ORM\Column]
    #[ApiProperty(writable: false)]
    public ?int $prixSuggere = null;

    /** Par défaut = prix suggéré ; ajustement limité à ±20 % */
    #[ORM\Column]
    #[Assert\Positive]
    #[ApiProperty(securityPostDenormalize: "is_granted('ROLE_ADMIN') or object.evaluation.representant == user")]
    public ?int $prixPropose = null;

    #[ORM\Column(type: 'text', nullable: true)]
    public ?string $justification = null;

    #[ORM\Column(type: 'smallint')]
    #[Assert\Positive]
    public int $delaiJours;

    #[ORM\Column(length: 40, nullable: true)]
    public ?string $typeVehicule = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $dateEmission = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $dateExpiration = null;

    #[ORM\Column(type: 'string', enumType: StatutDevis::class)]
    public StatutDevis $statut = StatutDevis::Propose;
}

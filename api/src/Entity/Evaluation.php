<?php

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\IriFilter;
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Patch;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\QueryParameter;
use App\Enum\EtatEmballage;
use App\State\EvaluationProcessor;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * Évaluation sur site par un représentant : check-in GPS (rayon 100 m), pesée, photos (min. 2 avant soumission).
 */
#[ORM\Entity]
#[ORM\Table(name: 'evaluation', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: [
            'demande' => new QueryParameter(filter: new IriFilter(), property: 'demande'),
            'representant' => new QueryParameter(filter: new IriFilter(), property: 'representant'),
        ]),
        new Get(),
        new Post(processor: EvaluationProcessor::class,
                 securityPostDenormalize: "is_granted('ROLE_ADMIN') or (is_granted('ROLE_REPRESENTANT') and object.representant == user)",
                 securityPostDenormalizeMessage: 'Seul un représentant peut accepter une mission, pour son propre compte.'),
        new Patch(processor: EvaluationProcessor::class, security: "is_granted('ROLE_ADMIN') or object.representant == user"),
    ],
    order: ['dateAcceptation' => 'DESC'],
)]
class Evaluation
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_evaluation', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_demande', referencedColumnName: 'id_demande', nullable: false, onDelete: 'CASCADE')]
    #[Assert\NotNull]
    public Demande $demande;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_representant', referencedColumnName: 'id_utilisateur', nullable: false)]
    #[Assert\NotNull]
    public Utilisateur $representant;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $dateAcceptation = null;

    #[ORM\Column(type: 'datetimetz_immutable', nullable: true)]
    public ?\DateTimeImmutable $dateCheckin = null;

    #[ORM\Column(type: 'decimal', precision: 9, scale: 6, nullable: true)]
    public ?string $latCheckin = null;

    #[ORM\Column(type: 'decimal', precision: 9, scale: 6, nullable: true)]
    public ?string $lngCheckin = null;

    /** Distance au point d'enlèvement lors du check-in (≤ 100 m exigé) */
    #[ORM\Column(nullable: true)]
    #[Assert\Range(min: 0, max: 100, notInRangeMessage: 'Le check-in doit être fait à moins de 100 m du point d\'enlèvement.')]
    public ?int $distanceCheckinM = null;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2, nullable: true)]
    #[Assert\Positive]
    public ?string $poidsReel = null;

    #[ORM\Column(type: 'decimal', precision: 8, scale: 2, nullable: true)]
    #[Assert\Positive]
    public ?string $volumeReel = null;

    #[ORM\Column(type: 'string', nullable: true, enumType: EtatEmballage::class)]
    public ?EtatEmballage $etatEmballage = null;

    #[ORM\Column(type: 'text', nullable: true)]
    public ?string $contraintes = null;

    /** Renseigner pour soumettre l'évaluation (refusé s'il y a moins de 2 photos) */
    #[ORM\Column(type: 'datetimetz_immutable', nullable: true)]
    public ?\DateTimeImmutable $dateSoumission = null;
}

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
use App\Enum\DecisionLitige;
use App\Enum\MotifLitige;
use App\Enum\StatutLitige;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

/** Litige sur une demande (la demande passe en LITIGE), arbitré par un administrateur. */
#[ORM\Entity]
#[ORM\Table(name: 'litige', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: [
            'statut' => new QueryParameter(filter: new ExactFilter(), property: 'statut'),
            'demande' => new QueryParameter(filter: new IriFilter(), property: 'demande'),
        ]),
        new Get(),
        new Post(securityPostDenormalize: "is_granted('ROLE_ADMIN') or object.ouvreur == user"),
        new Patch(security: "is_granted('ROLE_ADMIN')"),
    ],
    order: ['dateOuverture' => 'DESC'],
)]
#[Assert\Expression(
    "this.statut !== enum('App\\\\Enum\\\\StatutLitige::Resolu') or (this.decision !== null and this.admin !== null and this.dateResolution !== null)",
    message: 'Un litige résolu doit avoir une décision, un administrateur et une date de résolution.',
)]
#[Assert\Expression(
    "this.decision !== enum('App\\\\Enum\\\\DecisionLitige::RemboursementPartiel') or this.montantRembourse > 0",
    message: 'Indiquez le montant remboursé pour un remboursement partiel.',
)]
class Litige
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_litige', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\OneToOne]
    #[ORM\JoinColumn(name: 'id_demande', referencedColumnName: 'id_demande', nullable: false)]
    #[Assert\NotNull]
    public Demande $demande;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_ouvreur', referencedColumnName: 'id_utilisateur', nullable: false)]
    #[Assert\NotNull]
    public Utilisateur $ouvreur;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_admin', referencedColumnName: 'id_utilisateur')]
    public ?Utilisateur $admin = null;

    #[ORM\Column(type: 'string', enumType: MotifLitige::class)]
    #[Assert\NotNull]
    public MotifLitige $motif;

    #[ORM\Column(type: 'text')]
    #[Assert\NotBlank]
    public string $description;

    #[ORM\Column(type: 'string', enumType: StatutLitige::class)]
    public StatutLitige $statut = StatutLitige::Ouvert;

    #[ORM\Column(type: 'string', nullable: true, enumType: DecisionLitige::class)]
    public ?DecisionLitige $decision = null;

    #[ORM\Column(nullable: true)]
    #[Assert\PositiveOrZero]
    public ?int $montantRembourse = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $dateOuverture = null;

    #[ORM\Column(type: 'datetimetz_immutable', nullable: true)]
    public ?\DateTimeImmutable $dateResolution = null;

    /** Affichage back-office */
    public function getNumeroDemande(): ?string
    {
        return $this->demande->numero;
    }

    public function getNomOuvreur(): ?string
    {
        return $this->ouvreur->nomComplet;
    }
}

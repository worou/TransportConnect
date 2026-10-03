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
use App\Enum\MoyenPaiement;
use App\Enum\StatutPaiement;
use App\Enum\StatutSequestre;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Bridge\Doctrine\Validator\Constraints\UniqueEntity;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * Tentative de paiement d'un devis. Au passage à « reussi », la base bloque les fonds en séquestre,
 * accepte le devis et passe la demande en PAYE. La commission est calculée par la base.
 */
#[ORM\Entity]
#[ORM\Table(name: 'paiement', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: [
            'devis' => new QueryParameter(filter: new IriFilter(), property: 'devis'),
            'statut' => new QueryParameter(filter: new ExactFilter(), property: 'statut'),
            'statut_sequestre' => new QueryParameter(filter: new ExactFilter(), property: 'statutSequestre'),
        ]),
        new Get(security: "is_granted('ROLE_ADMIN') or object.devis.evaluation.demande.marchand == user"),
        new Post(securityPostDenormalize: "is_granted('ROLE_ADMIN') or object.devis.evaluation.demande.marchand == user",
                 securityPostDenormalizeMessage: 'Seul le marchand de la demande peut payer ce devis.'),
        new Patch(security: "is_granted('ROLE_ADMIN')"),
    ],
    order: ['createdAt' => 'DESC'],
)]
#[Assert\Expression(
    "this.moyen !== enum('App\\\\Enum\\\\MoyenPaiement::MobileMoney') or (this.operateur !== null and this.numeroPayeur !== null)",
    message: 'Opérateur et numéro obligatoires pour le Mobile Money.',
)]
#[UniqueEntity('referencePsp', message: 'Cette référence PSP est déjà enregistrée.')]
class Paiement
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_paiement', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_devis', referencedColumnName: 'id_devis', nullable: false)]
    #[Assert\NotNull]
    public Devis $devis;

    /** Montant en FCFA (XOF, entier) */
    #[ORM\Column]
    #[Assert\Positive]
    public int $montant;

    #[ORM\Column(length: 3, options: ['fixed' => true])]
    public string $devise = 'XOF';

    #[ORM\Column(type: 'string', enumType: MoyenPaiement::class)]
    #[Assert\NotNull]
    public MoyenPaiement $moyen;

    /** MTN, Moov, Wave, Orange… */
    #[ORM\Column(length: 30, nullable: true)]
    public ?string $operateur = null;

    #[ORM\Column(length: 20, nullable: true)]
    public ?string $numeroPayeur = null;

    #[ORM\Column(length: 100, unique: true, nullable: true)]
    public ?string $referencePsp = null;

    /** « reussi » / « echoue » : confirmé par le webhook du PSP ou un admin, jamais par l'app marchand */
    #[ORM\Column(type: 'string', enumType: StatutPaiement::class)]
    #[ApiProperty(securityPostDenormalize: "is_granted('ROLE_ADMIN')")]
    public StatutPaiement $statut = StatutPaiement::Initie;

    /** « bloque » automatiquement au succès du paiement, puis « libere » après livraison */
    #[ORM\Column(type: 'string', nullable: true, enumType: StatutSequestre::class)]
    #[ApiProperty(securityPostDenormalize: "is_granted('ROLE_ADMIN')")]
    public ?StatutSequestre $statutSequestre = null;

    #[ORM\Column(type: 'decimal', precision: 4, scale: 2)]
    #[ApiProperty(writable: false)]
    public string $tauxCommission = '7.00';

    #[ORM\Column(insertable: false, updatable: false, generated: 'ALWAYS')]
    #[ApiProperty(writable: false)]
    public ?int $montantCommission = null;

    #[ORM\Column(type: 'text', nullable: true)]
    public ?string $urlRecu = null;

    #[ORM\Column(type: 'text', nullable: true)]
    public ?string $motifEchec = null;

    #[ORM\Column(type: 'datetimetz_immutable', nullable: true)]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $datePaiement = null;

    #[ORM\Column(type: 'datetimetz_immutable', nullable: true)]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $dateLiberation = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $createdAt = null;

    /** Affichage back-office : numéro de la demande payée */
    public function getNumeroDemande(): ?string
    {
        return $this->devis->evaluation->demande->numero;
    }

    public function getNomMarchand(): ?string
    {
        return $this->devis->evaluation->demande->marchand->nomComplet;
    }
}

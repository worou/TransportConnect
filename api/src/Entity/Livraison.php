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
use App\Enum\StatutLivraison;
use App\State\LivraisonProcessor;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * Exécution du transport. Chaque changement de statut met à jour la demande (EN_TRANSIT, LIVRE).
 * Le passage à « livre » exige le code de réception communiqué au marchand.
 */
#[ORM\Entity]
#[ORM\Table(name: 'livraison', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: [
            'demande' => new QueryParameter(filter: new IriFilter(), property: 'demande'),
            'chauffeur' => new QueryParameter(filter: new IriFilter(), property: 'chauffeur'),
            'statut' => new QueryParameter(filter: new ExactFilter(), property: 'statut'),
        ]),
        new Get(),
        new Post(processor: LivraisonProcessor::class, security: "is_granted('ROLE_ADMIN') or is_granted('ROLE_REPRESENTANT')"),
        new Patch(processor: LivraisonProcessor::class,
                  security: "is_granted('ROLE_ADMIN') or object.chauffeur == user or is_granted('ROLE_REPRESENTANT')"),
    ],
)]
class Livraison
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_livraison', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\OneToOne]
    #[ORM\JoinColumn(name: 'id_demande', referencedColumnName: 'id_demande', nullable: false)]
    #[Assert\NotNull]
    public Demande $demande;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_chauffeur', referencedColumnName: 'id_utilisateur')]
    public ?Utilisateur $chauffeur = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_vehicule', referencedColumnName: 'id_vehicule')]
    public ?Vehicule $vehicule = null;

    /** Haché (SHA-256), jamais exposé */
    #[ORM\Column(type: 'text')]
    #[ApiProperty(readable: false, writable: false)]
    public ?string $codeOtpHash = null;

    /**
     * Code de réception à 4 chiffres (écriture seule) : généré par la plateforme à la création s'il est absent,
     * puis exigé pour passer la livraison au statut « livre ».
     */
    #[ApiProperty(readable: false, example: '4829')]
    #[Assert\Regex('/^\d{4}$/', message: 'Le code de réception comporte 4 chiffres.')]
    public ?string $codeReception = null;

    /** Code de réception en clair : visible du seul marchand de la demande (et des admins) */
    #[ORM\Column(length: 4, nullable: true)]
    #[ApiProperty(writable: false, security: "is_granted('ROLE_ADMIN') or object.demande.marchand == user")]
    public ?string $codeClair = null;

    #[ORM\Column(type: 'string', enumType: StatutLivraison::class)]
    public StatutLivraison $statut = StatutLivraison::PretEnlevement;

    #[ORM\Column(type: 'datetimetz_immutable', nullable: true)]
    public ?\DateTimeImmutable $dateEnlevementReel = null;

    #[ORM\Column(type: 'date_immutable', nullable: true)]
    public ?\DateTimeImmutable $dateArriveeEstimee = null;

    #[ORM\Column(type: 'datetimetz_immutable', nullable: true)]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $dateLivraison = null;

    #[ORM\Column(type: 'text', nullable: true)]
    public ?string $signatureUrl = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $createdAt = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'ALWAYS')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $updatedAt = null;

    /** Affichage (app marchand) */
    public function getNomChauffeur(): ?string
    {
        return $this->chauffeur?->nomComplet;
    }

    public function getTelephoneChauffeur(): ?string
    {
        return $this->chauffeur?->telephone;
    }

    public function getDescriptionVehicule(): ?string
    {
        return null === $this->vehicule ? null : $this->vehicule->typeVehicule.' · '.$this->vehicule->immatriculation;
    }
}

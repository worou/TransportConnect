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
use App\Enum\NiveauUrgence;
use App\Enum\StatutDemande;
use App\Enum\TypeMarchandise;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * Demande de transport d'un marchand. Le numéro TC-AAAA-NNNNN est attribué par la base,
 * chaque changement de statut est historisé (ressource HistoriqueStatut).
 */
#[ORM\Entity]
#[ORM\Table(name: 'demande', schema: 'transconnect')]
#[ApiResource(
    description: 'Demande de transport (ville A → ville B)',
    operations: [
        new GetCollection(parameters: [
            'marchand' => new QueryParameter(filter: new IriFilter(), property: 'marchand'),
            'statut' => new QueryParameter(filter: new ExactFilter(), property: 'statut'),
            'numero' => new QueryParameter(filter: new ExactFilter(), property: 'numero'),
            'ville_depart' => new QueryParameter(filter: new IriFilter(), property: 'villeDepart'),
        ]),
        // Représentants et chauffeurs consultent les demandes de leurs missions
        new Get(security: "is_granted('ROLE_ADMIN') or object.marchand == user or is_granted('ROLE_REPRESENTANT') or is_granted('ROLE_CHAUFFEUR')"),
        new Post(securityPostDenormalize: "is_granted('ROLE_ADMIN') or (is_granted('ROLE_MARCHAND') and object.marchand == user)",
                 securityPostDenormalizeMessage: 'Un marchand ne peut créer une demande que pour son propre compte.'),
        new Patch(security: "is_granted('ROLE_ADMIN') or object.marchand == user"),
    ],
    order: ['createdAt' => 'DESC'],
)]
#[Assert\Expression(
    'this.poidsEstime !== null or this.volumeEstime !== null or this.nbColis !== null',
    message: 'Indiquez au moins une quantité : poids, volume ou nombre de colis.',
)]
#[Assert\Expression('this.villeDepart !== this.villeArrivee', message: "La ville d'arrivée doit être différente de la ville de départ.")]
class Demande
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_demande', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    /** TC-AAAA-NNNNN, attribué par la base */
    #[ORM\Column(length: 20, unique: true, insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false, example: 'TC-2026-00123')]
    public ?string $numero = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_marchand', referencedColumnName: 'id_utilisateur', nullable: false)]
    #[Assert\NotNull]
    public Utilisateur $marchand;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_ville_depart', referencedColumnName: 'id_ville', nullable: false)]
    #[Assert\NotNull]
    public Ville $villeDepart;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_ville_arrivee', referencedColumnName: 'id_ville', nullable: false)]
    #[Assert\NotNull]
    public Ville $villeArrivee;

    #[ORM\Column(length: 255)]
    #[Assert\NotBlank]
    public string $adresseDepart;

    #[ORM\Column(length: 255)]
    #[Assert\NotBlank]
    public string $adresseArrivee;

    #[ORM\Column(type: 'string', enumType: TypeMarchandise::class)]
    #[Assert\NotNull]
    public TypeMarchandise $typeMarchandise;

    #[ORM\Column(length: 500)]
    #[Assert\NotBlank]
    #[Assert\Length(max: 500)]
    public string $description;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2, nullable: true)]
    #[Assert\Positive]
    public ?string $poidsEstime = null;

    #[ORM\Column(type: 'decimal', precision: 8, scale: 2, nullable: true)]
    #[Assert\Positive]
    public ?string $volumeEstime = null;

    #[ORM\Column(nullable: true)]
    #[Assert\Positive]
    public ?int $nbColis = null;

    #[ORM\Column(type: 'date_immutable')]
    #[Assert\NotNull]
    public \DateTimeImmutable $dateEnlevement;

    #[ORM\Column(type: 'string', enumType: NiveauUrgence::class)]
    public NiveauUrgence $urgence = NiveauUrgence::Normale;

    #[ORM\Column(length: 120, nullable: true)]
    public ?string $contactNom = null;

    #[ORM\Column(length: 20, nullable: true)]
    public ?string $contactTelephone = null;

    #[ORM\Column(length: 500, nullable: true)]
    public ?string $instructions = null;

    #[ORM\Column(type: 'decimal', precision: 7, scale: 1, nullable: true)]
    #[Assert\Positive]
    public ?string $distanceKm = null;

    #[ORM\Column(type: 'decimal', precision: 9, scale: 6, nullable: true)]
    public ?string $latDepart = null;

    #[ORM\Column(type: 'decimal', precision: 9, scale: 6, nullable: true)]
    public ?string $lngDepart = null;

    /**
     * Le marchand ne peut qu'annuler sa demande avant paiement ; les autres transitions sont faites par la plateforme
     * (évaluation, devis, paiement, livraison). Une valeur refusée est ignorée.
     */
    #[ORM\Column(type: 'string', enumType: StatutDemande::class)]
    #[ApiProperty(securityPostDenormalize: "is_granted('ROLE_ADMIN')
        or (previous_object === null and object.statut.value == 'EN_ATTENTE')
        or (previous_object !== null and object.statut == previous_object.statut)
        or (previous_object !== null and object.statut.value == 'ANNULE'
            and previous_object.statut.value in ['EN_ATTENTE', 'REPRESENTANT_ASSIGNE', 'EN_EVALUATION', 'PRIX_PROPOSE', 'EN_NEGOCIATION'])")]
    public StatutDemande $statut = StatutDemande::EnAttente;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $createdAt = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'ALWAYS')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $updatedAt = null;

    /** Affichage (apps) : villes et marchand sans requêtes supplémentaires */
    public function getNomVilleDepart(): string
    {
        return $this->villeDepart->nomVille;
    }

    public function getNomVilleArrivee(): string
    {
        return $this->villeArrivee->nomVille;
    }

    public function getNomMarchand(): ?string
    {
        return $this->marchand->nomComplet;
    }

    public function getTelephoneMarchand(): string
    {
        return $this->marchand->telephone;
    }
}

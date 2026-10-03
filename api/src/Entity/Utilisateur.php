<?php

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\ExactFilter;
use ApiPlatform\Doctrine\Orm\Filter\IriFilter;
use ApiPlatform\Doctrine\Orm\Filter\PartialSearchFilter;
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Patch;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\QueryParameter;
use App\Enum\Disponibilite;
use App\Enum\RoleUtilisateur;
use App\Enum\StatutCompte;
use App\State\MeProvider;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Bridge\Doctrine\Validator\Constraints\UniqueEntity;
use Symfony\Component\Security\Core\User\UserInterface;
use Symfony\Component\Serializer\Attribute\Ignore;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Validator\Context\ExecutionContextInterface;

/**
 * Marchand, représentant, chauffeur ou administrateur.
 * Seuls représentants et chauffeurs sont rattachés à un transporteur (contrainte en base).
 * Les marchands s'inscrivent eux-mêmes via /api/auth/verify-otp ; les autres comptes sont créés par un admin.
 */
#[ORM\Entity]
#[ORM\Table(name: 'utilisateur', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(
            security: "is_granted('ROLE_ADMIN')",
            parameters: [
                'role' => new QueryParameter(filter: new ExactFilter(), property: 'role'),
                'statut_compte' => new QueryParameter(filter: new ExactFilter(), property: 'statutCompte'),
                'transporteur' => new QueryParameter(filter: new IriFilter(), property: 'transporteur'),
                'nom_complet' => new QueryParameter(filter: new PartialSearchFilter(), property: 'nomComplet'),
                'telephone' => new QueryParameter(filter: new PartialSearchFilter(), property: 'telephone'),
            ],
            order: ['dateInscription' => 'DESC'],
        ),
        // Les représentants et chauffeurs ont besoin des coordonnées des marchands de leurs missions
        // Déclarée en premier : opération canonique pour les IRI (/api/utilisateurs/{id})
        new Get(security: "is_granted('ROLE_ADMIN') or object == user or not is_granted('ROLE_MARCHAND')"),
        new Get(
            uriTemplate: '/me',
            name: 'me',
            uriVariables: [],
            provider: MeProvider::class,
            description: "Profil de l'utilisateur connecté",
        ),
        new Post(security: "is_granted('ROLE_ADMIN')"),
        new Patch(security: "is_granted('ROLE_ADMIN') or object == user"),
    ],
)]
#[UniqueEntity('telephone', message: 'Ce numéro est déjà utilisé par un autre compte.')]
class Utilisateur implements UserInterface
{
    private const ADMIN_SEULEMENT = "is_granted('ROLE_ADMIN')";

    #[ORM\Id]
    #[ORM\Column(name: 'id_utilisateur', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    /** Identifiant de connexion : modifiable uniquement par un admin */
    #[ORM\Column(length: 20, unique: true)]
    #[Assert\NotBlank]
    #[Assert\Regex('/^\+[1-9][0-9]{7,14}$/', message: 'Numéro au format international attendu (+229…)')]
    #[ApiProperty(securityPostDenormalize: self::ADMIN_SEULEMENT)]
    public string $telephone;

    #[ORM\Column(length: 120, nullable: true)]
    public ?string $nomComplet = null;

    #[ORM\Column(type: 'string', enumType: RoleUtilisateur::class)]
    #[Assert\NotNull]
    #[ApiProperty(securityPostDenormalize: self::ADMIN_SEULEMENT)]
    public RoleUtilisateur $role;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_ville_residence', referencedColumnName: 'id_ville')]
    public ?Ville $villeResidence = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_transporteur', referencedColumnName: 'id_transporteur', onDelete: 'RESTRICT')]
    #[ApiProperty(securityPostDenormalize: self::ADMIN_SEULEMENT)]
    public ?Transporteur $transporteur = null;

    #[ORM\Column(length: 60, nullable: true)]
    public ?string $typeActivite = null;

    #[ORM\Column(type: 'text', nullable: true)]
    public ?string $avatarUrl = null;

    #[ORM\Column(type: 'string', enumType: StatutCompte::class)]
    #[ApiProperty(securityPostDenormalize: self::ADMIN_SEULEMENT)]
    public StatutCompte $statutCompte = StatutCompte::Actif;

    #[ORM\Column(type: 'string', nullable: true, enumType: Disponibilite::class)]
    public ?Disponibilite $disponibilite = null;

    #[ORM\Column(type: 'decimal', precision: 2, scale: 1, nullable: true)]
    #[ApiProperty(writable: false)]
    public ?string $noteMoyenne = null;

    #[ORM\Column]
    #[ApiProperty(writable: false)]
    public int $nbAvis = 0;

    /** Zones d'intervention (représentants uniquement) */
    #[ORM\ManyToMany(targetEntity: Ville::class)]
    #[ORM\JoinTable(name: 'zone_intervention', schema: 'transconnect')]
    #[ORM\JoinColumn(name: 'id_utilisateur', referencedColumnName: 'id_utilisateur', onDelete: 'CASCADE')]
    #[ORM\InverseJoinColumn(name: 'id_ville', referencedColumnName: 'id_ville')]
    #[ApiProperty(securityPostDenormalize: self::ADMIN_SEULEMENT)]
    public Collection $zonesIntervention;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $dateInscription = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'ALWAYS')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $updatedAt = null;

    public function __construct()
    {
        $this->zonesIntervention = new ArrayCollection();
    }

    /** Permet d'écrire les zones depuis l'API (liste d'IRI de villes). */
    public function setZonesIntervention(iterable $villes): void
    {
        $this->zonesIntervention->clear();
        foreach ($villes as $ville) {
            $this->zonesIntervention->add($ville);
        }
    }

    /** ROLE_MARCHAND, ROLE_REPRESENTANT, ROLE_CHAUFFEUR ou ROLE_ADMIN */
    #[Ignore]
    public function getRoles(): array
    {
        return ['ROLE_'.strtoupper($this->role->value)];
    }

    #[Ignore]
    public function getUserIdentifier(): string
    {
        return $this->telephone;
    }

    /** Affichage back-office */
    public function getNomTransporteur(): ?string
    {
        return $this->transporteur?->raisonSociale;
    }

    /** Seuls représentants et chauffeurs sont rattachés à un transporteur (miroir de ck_utilisateur_transporteur). */
    #[Assert\Callback]
    public function validerRattachement(ExecutionContextInterface $context): void
    {
        if (!isset($this->role)) {
            return;
        }
        $rattache = \in_array($this->role, [RoleUtilisateur::Representant, RoleUtilisateur::Chauffeur], true);
        if ($rattache !== (null !== $this->transporteur)) {
            $context->buildViolation($rattache
                ? 'Un représentant ou un chauffeur doit être rattaché à un transporteur.'
                : 'Seuls les représentants et les chauffeurs sont rattachés à un transporteur.')
                ->atPath('transporteur')
                ->addViolation();
        }
    }

    public function eraseCredentials(): void
    {
    }
}

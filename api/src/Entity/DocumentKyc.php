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
use App\Enum\StatutVerification;
use App\Enum\TypeDocument;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Entity]
#[ORM\Table(name: 'document_kyc', schema: 'transconnect')]
#[ApiResource(
    description: 'Pièces justificatives (KYC) déposées par un utilisateur',
    operations: [
        new GetCollection(parameters: [
            'utilisateur' => new QueryParameter(filter: new IriFilter(), property: 'utilisateur'),
            'statut_verification' => new QueryParameter(filter: new ExactFilter(), property: 'statutVerification'),
        ]),
        new Get(security: "is_granted('ROLE_ADMIN') or object.utilisateur == user"),
        new Post(securityPostDenormalize: "is_granted('ROLE_ADMIN') or object.utilisateur == user"),
        new Patch(security: "is_granted('ROLE_ADMIN')"),
    ],
)]
class DocumentKyc
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_document', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_utilisateur', referencedColumnName: 'id_utilisateur', nullable: false, onDelete: 'CASCADE')]
    #[Assert\NotNull]
    public Utilisateur $utilisateur;

    #[ORM\Column(type: 'string', enumType: TypeDocument::class)]
    #[Assert\NotNull]
    public TypeDocument $typeDocument;

    #[ORM\Column(type: 'text')]
    #[Assert\NotBlank]
    public string $urlFichier;

    #[ORM\Column(type: 'string', enumType: StatutVerification::class)]
    public StatutVerification $statutVerification = StatutVerification::EnAttente;

    #[ORM\Column(type: 'text', nullable: true)]
    public ?string $motifRejet = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $dateDepot = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'verifie_par', referencedColumnName: 'id_utilisateur')]
    public ?Utilisateur $verifiePar = null;

    #[ORM\Column(type: 'datetimetz_immutable', nullable: true)]
    public ?\DateTimeImmutable $verifieLe = null;

    /** Affichage back-office */
    public function getNomUtilisateur(): ?string
    {
        return $this->utilisateur->nomComplet;
    }

    public function getTelephoneUtilisateur(): string
    {
        return $this->utilisateur->telephone;
    }
}

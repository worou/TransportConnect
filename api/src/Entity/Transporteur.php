<?php

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\ExactFilter;
use ApiPlatform\Doctrine\Orm\Filter\PartialSearchFilter;
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Patch;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\QueryParameter;
use App\Enum\StatutCompte;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Bridge\Doctrine\Validator\Constraints\UniqueEntity;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Entity]
#[ORM\Table(name: 'transporteur', schema: 'transconnect')]
#[ApiResource(
    description: 'Compagnie de transport (entreprise)',
    operations: [
        new GetCollection(parameters: [
            'statut' => new QueryParameter(filter: new ExactFilter(), property: 'statut'),
            'raison_sociale' => new QueryParameter(filter: new PartialSearchFilter(), property: 'raisonSociale'),
        ]),
        new Get(),
        new Post(security: "is_granted('ROLE_ADMIN')"), new Patch(security: "is_granted('ROLE_ADMIN')"),
    ],
)]
#[UniqueEntity('numRccm', message: 'Un transporteur est déjà enregistré avec ce numéro RCCM.')]
class Transporteur
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_transporteur', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\Column(length: 150)]
    #[Assert\NotBlank]
    public string $raisonSociale;

    /** Numéro du registre du commerce (RCCM) */
    #[ORM\Column(length: 50, unique: true)]
    #[Assert\NotBlank]
    public string $numRccm;

    #[ORM\Column(length: 20)]
    #[Assert\NotBlank]
    #[Assert\Regex('/^\+[1-9][0-9]{7,14}$/', message: 'Numéro au format international attendu (+229…)')]
    public string $telephone;

    #[ORM\Column(length: 20)]
    #[Assert\Choice(['gratuit', 'premium'])]
    public string $abonnement = 'gratuit';

    #[ORM\Column(type: 'decimal', precision: 2, scale: 1, nullable: true)]
    #[ApiProperty(writable: false)]
    public ?string $noteMoyenne = null;

    #[ORM\Column]
    #[ApiProperty(writable: false)]
    public int $nbAvis = 0;

    #[ORM\Column(type: 'string', enumType: StatutCompte::class)]
    public StatutCompte $statut = StatutCompte::EnAttenteValidation;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $createdAt = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'ALWAYS')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $updatedAt = null;
}

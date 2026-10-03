<?php

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\IriFilter;
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\QueryParameter;
use App\Enum\TypeAuteurAvis;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

/** Notation réciproque après livraison ; met à jour les notes moyennes du transporteur ou du marchand. */
#[ORM\Entity]
#[ORM\Table(name: 'avis', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: ['livraison' => new QueryParameter(filter: new IriFilter(), property: 'livraison')]),
        new Get(), new Post(),
    ],
)]
class Avis
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_avis', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_livraison', referencedColumnName: 'id_livraison', nullable: false, onDelete: 'CASCADE')]
    #[Assert\NotNull]
    public Livraison $livraison;

    #[ORM\Column(type: 'string', enumType: TypeAuteurAvis::class)]
    #[Assert\NotNull]
    public TypeAuteurAvis $typeAuteur;

    #[ORM\Column(type: 'smallint')]
    #[Assert\Range(min: 1, max: 5)]
    public int $note;

    #[ORM\Column(length: 500, nullable: true)]
    #[Assert\Length(max: 500)]
    public ?string $commentaire = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $dateAvis = null;
}

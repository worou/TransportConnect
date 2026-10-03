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
use App\Enum\TypeIncident;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Entity]
#[ORM\Table(name: 'incident', schema: 'transconnect')]
#[ApiResource(
    description: 'Incident signalé pendant le transport (panne, accident, retard…)',
    operations: [
        new GetCollection(parameters: ['livraison' => new QueryParameter(filter: new IriFilter(), property: 'livraison')]),
        new Get(), new Post(), new Patch(),
    ],
)]
class Incident
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_incident', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_livraison', referencedColumnName: 'id_livraison', nullable: false, onDelete: 'CASCADE')]
    #[Assert\NotNull]
    public Livraison $livraison;

    #[ORM\Column(type: 'string', enumType: TypeIncident::class)]
    #[Assert\NotNull]
    public TypeIncident $typeIncident;

    #[ORM\Column(type: 'text')]
    #[Assert\NotBlank]
    public string $description;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $dateSignalement = null;

    #[ORM\Column(type: 'datetimetz_immutable', nullable: true)]
    public ?\DateTimeImmutable $resoluLe = null;
}

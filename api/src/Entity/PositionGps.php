<?php

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\IriFilter;
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\QueryParameter;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Validator\Constraints as Assert;

/** Point de suivi GPS d'un véhicule en cours de livraison (carte temps réel). */
#[ORM\Entity]
#[ORM\Table(name: 'position_gps', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: ['livraison' => new QueryParameter(filter: new IriFilter(), property: 'livraison')]),
        new Get(), new Post(),
    ],
    order: ['horodatage' => 'DESC'],
)]
class PositionGps
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_position', type: 'bigint')]
    #[ORM\GeneratedValue(strategy: 'IDENTITY')]
    public ?int $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_livraison', referencedColumnName: 'id_livraison', nullable: false, onDelete: 'CASCADE')]
    #[Assert\NotNull]
    public Livraison $livraison;

    #[ORM\Column(type: 'decimal', precision: 9, scale: 6)]
    #[Assert\NotBlank]
    #[Assert\Range(min: -90, max: 90)]
    public string $latitude;

    #[ORM\Column(type: 'decimal', precision: 9, scale: 6)]
    #[Assert\NotBlank]
    #[Assert\Range(min: -180, max: 180)]
    public string $longitude;

    #[ORM\Column(type: 'decimal', precision: 5, scale: 1, nullable: true)]
    public ?string $vitesseKmh = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $horodatage = null;
}

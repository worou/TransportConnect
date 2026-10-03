<?php

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\ExactFilter;
use ApiPlatform\Doctrine\Orm\Filter\IriFilter;
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Delete;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Patch;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\QueryParameter;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Bridge\Doctrine\Validator\Constraints\UniqueEntity;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Entity]
#[ORM\Table(name: 'vehicule', schema: 'transconnect')]
#[ApiResource(
    description: "Flotte d'un transporteur",
    operations: [
        new GetCollection(parameters: [
            'transporteur' => new QueryParameter(filter: new IriFilter(), property: 'transporteur'),
            'actif' => new QueryParameter(filter: new ExactFilter(), property: 'actif'),
        ]),
        new Get(),
        new Post(security: "is_granted('ROLE_ADMIN')"), new Patch(security: "is_granted('ROLE_ADMIN')"), new Delete(security: "is_granted('ROLE_ADMIN')"),
    ],
)]
#[UniqueEntity('immatriculation', message: 'Un véhicule porte déjà cette immatriculation.')]
class Vehicule
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_vehicule', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_transporteur', referencedColumnName: 'id_transporteur', nullable: false, onDelete: 'CASCADE')]
    #[Assert\NotNull]
    public Transporteur $transporteur;

    #[ORM\Column(length: 20, unique: true)]
    #[Assert\NotBlank]
    public string $immatriculation;

    /** ex : Camion 5 T */
    #[ORM\Column(length: 40)]
    #[Assert\NotBlank]
    public string $typeVehicule;

    #[ORM\Column]
    #[Assert\Positive]
    public int $capaciteKg;

    #[ORM\Column(type: 'decimal', precision: 6, scale: 2, nullable: true)]
    public ?string $capaciteM3 = null;

    #[ORM\Column]
    public bool $gpsActif = false;

    #[ORM\Column]
    public bool $actif = true;
}

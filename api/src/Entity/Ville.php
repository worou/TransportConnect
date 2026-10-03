<?php

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\ExactFilter;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Delete;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Patch;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\QueryParameter;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Validator\Constraints\UniqueEntity;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Entity]
#[ORM\Table(name: 'ville', schema: 'transconnect')]
#[ApiResource(
    description: 'Villes et zones couvertes par la plateforme',
    operations: [
        new GetCollection(parameters: ['est_couverte' => new QueryParameter(filter: new ExactFilter(), property: 'estCouverte')]),
        new Get(),
        new Post(security: "is_granted('ROLE_ADMIN')"), new Patch(security: "is_granted('ROLE_ADMIN')"), new Delete(security: "is_granted('ROLE_ADMIN')"),
    ],
    order: ['nomVille' => 'ASC'],
)]
#[UniqueEntity(['nomVille', 'pays'], message: 'Cette ville existe déjà.', errorPath: 'nomVille')]
class Ville
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_ville', type: 'smallint')]
    #[ORM\GeneratedValue(strategy: 'IDENTITY')]
    public ?int $id = null;

    #[ORM\Column(length: 80)]
    #[Assert\NotBlank]
    public string $nomVille;

    /** Code pays ISO 3166-1 alpha-2 */
    #[ORM\Column(length: 2, options: ['fixed' => true])]
    #[Assert\Length(exactly: 2)]
    public string $pays = 'BJ';

    #[ORM\Column]
    public bool $estCouverte = true;

    #[ORM\Column(type: 'decimal', precision: 9, scale: 6, nullable: true)]
    public ?string $latitude = null;

    #[ORM\Column(type: 'decimal', precision: 9, scale: 6, nullable: true)]
    public ?string $longitude = null;
}

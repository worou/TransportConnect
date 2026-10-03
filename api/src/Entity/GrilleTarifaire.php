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
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * Prix suggéré = (prix_base + distance × tarif_km + poids × tarif_kg) × coef type + supplément express,
 * arrondi à la centaine (fonction SQL calculer_prix_suggere).
 */
#[ORM\Entity]
#[ORM\Table(name: 'grille_tarifaire', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: [
            'transporteur' => new QueryParameter(filter: new IriFilter(), property: 'transporteur'),
            'actif' => new QueryParameter(filter: new ExactFilter(), property: 'actif'),
        ]),
        new Get(),
        new Post(security: "is_granted('ROLE_ADMIN')"), new Patch(security: "is_granted('ROLE_ADMIN')"),
    ],
)]
class GrilleTarifaire
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_grille', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_transporteur', referencedColumnName: 'id_transporteur', nullable: false, onDelete: 'CASCADE')]
    #[Assert\NotNull]
    public Transporteur $transporteur;

    #[ORM\Column]
    #[Assert\PositiveOrZero]
    public int $prixBase;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2)]
    #[Assert\NotBlank]
    public string $tarifKm;

    #[ORM\Column(type: 'decimal', precision: 10, scale: 2)]
    #[Assert\NotBlank]
    public string $tarifKg;

    #[ORM\Column]
    #[Assert\PositiveOrZero]
    public int $supplementExpress = 0;

    /** Coefficient multiplicateur par type de marchandise */
    #[ORM\Column(type: 'json', options: ['jsonb' => true])]
    public array $coefTypeMarchandise = ['standard' => 1.0, 'alimentaire' => 1.1, 'fragile' => 1.3, 'dangereuse' => 1.5, 'betail' => 1.4];

    #[ORM\Column(type: 'date_immutable')]
    public \DateTimeImmutable $dateEffet;

    #[ORM\Column]
    public bool $actif = true;

    public function __construct()
    {
        $this->dateEffet = new \DateTimeImmutable('today');
    }
}

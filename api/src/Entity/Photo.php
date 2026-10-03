<?php

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\IriFilter;
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Delete;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\QueryParameter;
use App\Enum\ContextePhoto;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * Photo rattachée à une demande, une évaluation OU une livraison (une seule, selon le contexte).
 */
#[ORM\Entity]
#[ORM\Table(name: 'photo', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: [
            'demande' => new QueryParameter(filter: new IriFilter(), property: 'demande'),
            'evaluation' => new QueryParameter(filter: new IriFilter(), property: 'evaluation'),
            'livraison' => new QueryParameter(filter: new IriFilter(), property: 'livraison'),
        ]),
        new Get(), new Post(), new Delete(),
    ],
)]
#[Assert\Expression(
    "(this.contexte === enum('App\\\\Enum\\\\ContextePhoto::Demande') and this.demande !== null and this.evaluation === null and this.livraison === null)
     or (this.contexte === enum('App\\\\Enum\\\\ContextePhoto::Evaluation') and this.evaluation !== null and this.demande === null and this.livraison === null)
     or (this.contexte === enum('App\\\\Enum\\\\ContextePhoto::Livraison') and this.livraison !== null and this.demande === null and this.evaluation === null)",
    message: 'Renseignez uniquement la ressource correspondant au contexte (demande, evaluation ou livraison).',
)]
class Photo
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_photo', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\Column(type: 'text')]
    #[Assert\NotBlank]
    public string $url;

    #[ORM\Column(type: 'string', enumType: ContextePhoto::class)]
    #[Assert\NotNull]
    public ContextePhoto $contexte;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_demande', referencedColumnName: 'id_demande', onDelete: 'CASCADE')]
    public ?Demande $demande = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_evaluation', referencedColumnName: 'id_evaluation', onDelete: 'CASCADE')]
    public ?Evaluation $evaluation = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_livraison', referencedColumnName: 'id_livraison', onDelete: 'CASCADE')]
    public ?Livraison $livraison = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $datePrise = null;
}

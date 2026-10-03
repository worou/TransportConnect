<?php

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\IriFilter;
use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\QueryParameter;
use App\Enum\EmetteurMessage;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

/** Négociation d'un devis : 3 allers-retours maximum (contrôlé par la base). */
#[ORM\Entity]
#[ORM\Table(name: 'message_negociation', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: ['devis' => new QueryParameter(filter: new IriFilter(), property: 'devis')]),
        new Get(), new Post(),
    ],
    order: ['dateEnvoi' => 'ASC'],
)]
#[Assert\Expression('this.prixContreOffre !== null or this.message !== null', message: 'Indiquez un message ou une contre-offre.')]
class MessageNegociation
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_message', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_devis', referencedColumnName: 'id_devis', nullable: false, onDelete: 'CASCADE')]
    #[Assert\NotNull]
    public Devis $devis;

    #[ORM\Column(type: 'string', enumType: EmetteurMessage::class)]
    #[Assert\NotNull]
    public EmetteurMessage $emetteur;

    #[ORM\Column(nullable: true)]
    #[Assert\Positive]
    public ?int $prixContreOffre = null;

    #[ORM\Column(length: 200, nullable: true)]
    #[Assert\Length(max: 200)]
    public ?string $message = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $dateEnvoi = null;
}

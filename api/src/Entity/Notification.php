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
use App\Enum\CanalNotification;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;

#[ORM\Entity]
#[ORM\Table(name: 'notification', schema: 'transconnect')]
#[ApiResource(
    operations: [
        new GetCollection(parameters: [
            'utilisateur' => new QueryParameter(filter: new IriFilter(), property: 'utilisateur'),
            'est_lue' => new QueryParameter(filter: new ExactFilter(), property: 'estLue'),
        ]),
        new Get(security: "is_granted('ROLE_ADMIN') or object.utilisateur == user"),
        new Post(security: "is_granted('ROLE_ADMIN')"),
        new Patch(security: "is_granted('ROLE_ADMIN') or object.utilisateur == user"),
    ],
    order: ['dateEnvoi' => 'DESC'],
)]
class Notification
{
    #[ORM\Id]
    #[ORM\Column(name: 'id_notification', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    #[ApiProperty(writable: false)]
    public ?Uuid $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_utilisateur', referencedColumnName: 'id_utilisateur', nullable: false, onDelete: 'CASCADE')]
    #[Assert\NotNull]
    public Utilisateur $utilisateur;

    #[ORM\Column(type: 'string', enumType: CanalNotification::class)]
    #[Assert\NotNull]
    public CanalNotification $canal;

    #[ORM\Column(length: 120)]
    #[Assert\NotBlank]
    public string $titre;

    #[ORM\Column(type: 'text')]
    #[Assert\NotBlank]
    public string $contenu;

    /** Lien interne, ex : demande/TC-2026-00123 */
    #[ORM\Column(type: 'text', nullable: true)]
    public ?string $lienCible = null;

    #[ORM\Column]
    public bool $estLue = false;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    #[ApiProperty(writable: false)]
    public ?\DateTimeImmutable $dateEnvoi = null;
}

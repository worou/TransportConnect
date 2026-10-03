<?php

namespace App\Entity;

use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;

/** Jeton de renouvellement (haché, à usage unique). Usage interne : non exposé dans l'API. */
#[ORM\Entity]
#[ORM\Table(name: 'refresh_token', schema: 'transconnect')]
class RefreshToken
{
    public const DUREE_VALIDITE = '+30 days';

    #[ORM\Id]
    #[ORM\Column(name: 'id_token', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    public ?Uuid $id = null;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(name: 'id_utilisateur', referencedColumnName: 'id_utilisateur', nullable: false, onDelete: 'CASCADE')]
    public Utilisateur $utilisateur;

    #[ORM\Column(type: 'text', unique: true)]
    public string $tokenHash;

    #[ORM\Column(type: 'datetimetz_immutable')]
    public \DateTimeImmutable $expireLe;

    #[ORM\Column(type: 'datetimetz_immutable', nullable: true)]
    public ?\DateTimeImmutable $revoqueLe = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    public ?\DateTimeImmutable $createdAt = null;

    public function __construct(Utilisateur $utilisateur, string $tokenHash)
    {
        $this->utilisateur = $utilisateur;
        $this->tokenHash = $tokenHash;
        $this->expireLe = new \DateTimeImmutable(self::DUREE_VALIDITE);
    }

    public function estValide(): bool
    {
        return null === $this->revoqueLe && $this->expireLe > new \DateTimeImmutable();
    }
}

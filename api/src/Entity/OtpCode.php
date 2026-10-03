<?php

namespace App\Entity;

use Doctrine\ORM\Mapping as ORM;
use Symfony\Bridge\Doctrine\Types\UuidType;
use Symfony\Component\Uid\Uuid;

/** Code OTP envoyé par SMS (haché). Usage interne : non exposé dans l'API. */
#[ORM\Entity]
#[ORM\Table(name: 'otp_code', schema: 'transconnect')]
class OtpCode
{
    public const DUREE_VALIDITE = 300;       // secondes
    public const MAX_TENTATIVES = 3;

    #[ORM\Id]
    #[ORM\Column(name: 'id_otp', type: UuidType::NAME)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    public ?Uuid $id = null;

    #[ORM\Column(length: 20)]
    public string $telephone;

    #[ORM\Column(type: 'text')]
    public string $codeHash;

    #[ORM\Column(type: 'smallint')]
    public int $tentatives = 0;

    #[ORM\Column(type: 'datetimetz_immutable')]
    public \DateTimeImmutable $expireLe;

    #[ORM\Column(type: 'datetimetz_immutable', nullable: true)]
    public ?\DateTimeImmutable $utiliseLe = null;

    #[ORM\Column(type: 'datetimetz_immutable', insertable: false, updatable: false, generated: 'INSERT')]
    public ?\DateTimeImmutable $createdAt = null;

    public function __construct(string $telephone, string $codeHash)
    {
        $this->telephone = $telephone;
        $this->codeHash = $codeHash;
        $this->expireLe = new \DateTimeImmutable('+'.self::DUREE_VALIDITE.' seconds');
    }
}

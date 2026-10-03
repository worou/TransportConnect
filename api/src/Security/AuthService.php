<?php

namespace App\Security;

use App\ApiResource\Auth\Jetons;
use App\Entity\OtpCode;
use App\Entity\RefreshToken;
use App\Entity\Utilisateur;
use Doctrine\ORM\EntityManagerInterface;
use Lexik\Bundle\JWTAuthenticationBundle\Services\JWTTokenManagerInterface;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

/** Hachage des codes OTP et émission des jetons (JWT + refresh token). */
final class AuthService
{
    public function __construct(
        private readonly EntityManagerInterface $em,
        private readonly JWTTokenManagerInterface $jwtManager,
        #[Autowire('%kernel.secret%')] private readonly string $secret,
        #[Autowire('%lexik_jwt_authentication.token_ttl%')] private readonly int $tokenTtl,
    ) {
    }

    public function hacherOtp(string $code): string
    {
        return hash_hmac('sha256', $code, $this->secret);
    }

    public function otpCorrect(OtpCode $otp, string $code): bool
    {
        return hash_equals($otp->codeHash, $this->hacherOtp($code));
    }

    /** Crée un JWT et un refresh token (stocké haché). L'appelant fait le flush. */
    public function emettreJetons(Utilisateur $utilisateur, bool $nouveauCompte = false): Jetons
    {
        $refresh = bin2hex(random_bytes(32));
        $this->em->persist(new RefreshToken($utilisateur, hash('sha256', $refresh)));

        return new Jetons($this->jwtManager->create($utilisateur), $refresh, $this->tokenTtl, $utilisateur, $nouveauCompte);
    }

    public function trouverRefreshToken(string $refresh): ?RefreshToken
    {
        return $this->em->getRepository(RefreshToken::class)->findOneBy(['tokenHash' => hash('sha256', $refresh)]);
    }
}

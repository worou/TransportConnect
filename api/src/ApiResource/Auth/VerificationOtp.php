<?php

namespace App\ApiResource\Auth;

use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Post;
use ApiPlatform\OpenApi\Model\Operation;
use App\State\Auth\VerificationOtpProcessor;
use Symfony\Component\Validator\Constraints as Assert;

/** Étape 2 : vérification du code, création du compte marchand si le numéro est inconnu, émission des jetons. */
#[ApiResource(
    operations: [
        new Post(
            uriTemplate: '/auth/verify-otp',
            status: 200,
            output: Jetons::class,
            processor: VerificationOtpProcessor::class,
            openapi: new Operation(
                tags: ['Authentification'],
                summary: 'Vérifie le code OTP et renvoie un JWT',
                description: "Si le numéro n'a pas encore de compte, un compte marchand est créé (nouveau_compte = true). Les comptes représentant, chauffeur et admin sont créés par un administrateur.",
            ),
        ),
    ],
)]
final class VerificationOtp
{
    #[Assert\NotBlank]
    #[Assert\Uuid]
    public string $otpId;

    #[Assert\NotBlank]
    #[Assert\Regex('/^\d{6}$/', message: 'Le code comporte 6 chiffres.')]
    #[ApiProperty(example: '123456')]
    public string $code;

    /** Utilisé uniquement à l'inscription */
    #[Assert\Length(max: 120)]
    public ?string $nomComplet = null;

    /**
     * Espace demandé : « admin » (back-office) ou « representant » (app mobile, représentants et chauffeurs) :
     * le compte doit exister avec ce rôle, aucun compte n'est créé. « marchand » : compte marchand créé si besoin,
     * refusé si le numéro appartient à un autre rôle.
     */
    #[Assert\Choice(['admin', 'representant', 'marchand'])]
    public ?string $espace = null;
}

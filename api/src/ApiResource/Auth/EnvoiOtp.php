<?php

namespace App\ApiResource\Auth;

use ApiPlatform\Metadata\ApiProperty;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Post;
use ApiPlatform\OpenApi\Model\Operation;
use App\State\Auth\EnvoiOtpProcessor;
use Symfony\Component\Validator\Constraints as Assert;

/** Étape 1 de la connexion / inscription : envoi d'un code à 6 chiffres par SMS. */
#[ApiResource(
    operations: [
        new Post(
            uriTemplate: '/auth/send-otp',
            status: 200,
            output: OtpEnvoye::class,
            processor: EnvoiOtpProcessor::class,
            openapi: new Operation(
                tags: ['Authentification'],
                summary: 'Envoie un code OTP par SMS',
                description: "Valable 5 minutes, 3 essais. Au plus 3 envois par numéro sur 15 minutes. Avec OTP_DEBUG=1 (développement), le code est renvoyé dans « code_dev ».",
            ),
        ),
    ],
)]
final class EnvoiOtp
{
    #[Assert\NotBlank]
    #[Assert\Regex('/^\+[1-9][0-9]{7,14}$/', message: 'Numéro au format international attendu (+229…)')]
    #[ApiProperty(example: '+22997123456')]
    public string $telephone;
}

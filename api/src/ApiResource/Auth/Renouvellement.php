<?php

namespace App\ApiResource\Auth;

use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Post;
use ApiPlatform\OpenApi\Model\Operation;
use App\State\Auth\DeconnexionProcessor;
use App\State\Auth\RenouvellementProcessor;
use Symfony\Component\Validator\Constraints as Assert;

/** Renouvellement du JWT (rotation du refresh token) et déconnexion (révocation). */
#[ApiResource(
    operations: [
        new Post(
            uriTemplate: '/auth/refresh',
            status: 200,
            output: Jetons::class,
            processor: RenouvellementProcessor::class,
            openapi: new Operation(
                tags: ['Authentification'],
                summary: 'Renouvelle le JWT à partir du refresh token',
                description: "Le refresh token utilisé est révoqué et un nouveau est renvoyé (valable 30 jours).",
            ),
        ),
        new Post(
            uriTemplate: '/auth/logout',
            status: 204,
            output: false,
            processor: DeconnexionProcessor::class,
            openapi: new Operation(tags: ['Authentification'], summary: 'Révoque le refresh token'),
        ),
    ],
)]
final class Renouvellement
{
    #[Assert\NotBlank]
    public string $refreshToken;
}

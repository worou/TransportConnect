<?php

namespace App\State\Auth;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProcessorInterface;
use App\ApiResource\Auth\Jetons;
use App\ApiResource\Auth\Renouvellement;
use App\Enum\StatutCompte;
use App\Security\AuthService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpKernel\Exception\UnauthorizedHttpException;

/** Rotation : l'ancien refresh token est révoqué, un nouveau est émis avec le JWT. */
final class RenouvellementProcessor implements ProcessorInterface
{
    public function __construct(
        private readonly EntityManagerInterface $em,
        private readonly AuthService $auth,
    ) {
    }

    /** @param Renouvellement $data */
    public function process(mixed $data, Operation $operation, array $uriVariables = [], array $context = []): Jetons
    {
        $ancien = $this->auth->trouverRefreshToken($data->refreshToken);

        if (null === $ancien || !$ancien->estValide() || StatutCompte::Suspendu === $ancien->utilisateur->statutCompte) {
            throw new UnauthorizedHttpException('Bearer', 'Refresh token invalide, expiré ou révoqué.');
        }

        $ancien->revoqueLe = new \DateTimeImmutable();
        $jetons = $this->auth->emettreJetons($ancien->utilisateur);
        $this->em->flush();

        return $jetons;
    }
}

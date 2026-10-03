<?php

namespace App\State\Auth;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProcessorInterface;
use App\ApiResource\Auth\Renouvellement;
use App\Security\AuthService;
use Doctrine\ORM\EntityManagerInterface;

/** Révoque le refresh token. Le JWT déjà émis reste valable jusqu'à son expiration (1 h). */
final class DeconnexionProcessor implements ProcessorInterface
{
    public function __construct(
        private readonly EntityManagerInterface $em,
        private readonly AuthService $auth,
    ) {
    }

    /** @param Renouvellement $data */
    public function process(mixed $data, Operation $operation, array $uriVariables = [], array $context = []): null
    {
        $jeton = $this->auth->trouverRefreshToken($data->refreshToken);
        if (null !== $jeton && null === $jeton->revoqueLe) {
            $jeton->revoqueLe = new \DateTimeImmutable();
            $this->em->flush();
        }

        return null;
    }
}

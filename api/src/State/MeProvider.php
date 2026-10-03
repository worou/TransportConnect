<?php

namespace App\State;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProviderInterface;
use App\Entity\Utilisateur;
use Symfony\Bundle\SecurityBundle\Security;

/** GET /api/me : l'utilisateur authentifié par le JWT. */
final class MeProvider implements ProviderInterface
{
    public function __construct(private readonly Security $security)
    {
    }

    public function provide(Operation $operation, array $uriVariables = [], array $context = []): ?Utilisateur
    {
        $user = $this->security->getUser();

        return $user instanceof Utilisateur ? $user : null;
    }
}

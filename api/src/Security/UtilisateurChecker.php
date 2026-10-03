<?php

namespace App\Security;

use App\Entity\Utilisateur;
use App\Enum\StatutCompte;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Exception\CustomUserMessageAccountStatusException;
use Symfony\Component\Security\Core\User\UserCheckerInterface;
use Symfony\Component\Security\Core\User\UserInterface;

/** Un compte suspendu est refusé, même avec un JWT encore valide. */
final class UtilisateurChecker implements UserCheckerInterface
{
    public function checkPreAuth(UserInterface $user): void
    {
        if ($user instanceof Utilisateur && StatutCompte::Suspendu === $user->statutCompte) {
            throw new CustomUserMessageAccountStatusException('Compte suspendu. Contactez le support.');
        }
    }

    public function checkPostAuth(UserInterface $user, ?TokenInterface $token = null): void
    {
    }
}

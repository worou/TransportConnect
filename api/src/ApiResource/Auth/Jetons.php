<?php

namespace App\ApiResource\Auth;

use App\Entity\Utilisateur;

final class Jetons
{
    public readonly string $tokenType;
    public readonly string $userId;
    public readonly string $role;
    /** IRI du profil, ex : /api/utilisateurs/… */
    public readonly Utilisateur $utilisateur;

    public function __construct(
        public readonly string $accessToken,
        public readonly string $refreshToken,
        public readonly int $expiresIn,
        Utilisateur $utilisateur,
        public readonly bool $nouveauCompte = false,
    ) {
        $this->tokenType = 'Bearer';
        $this->utilisateur = $utilisateur;
        $this->userId = $utilisateur->id->toRfc4122();
        $this->role = $utilisateur->role->value;
    }
}

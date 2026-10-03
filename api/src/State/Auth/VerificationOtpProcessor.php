<?php

namespace App\State\Auth;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProcessorInterface;
use App\ApiResource\Auth\Jetons;
use App\ApiResource\Auth\VerificationOtp;
use App\Entity\OtpCode;
use App\Entity\Utilisateur;
use App\Enum\RoleUtilisateur;
use App\Enum\StatutCompte;
use App\Security\AuthService;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

final class VerificationOtpProcessor implements ProcessorInterface
{
    public function __construct(
        private readonly EntityManagerInterface $em,
        private readonly AuthService $auth,
    ) {
    }

    /** @param VerificationOtp $data */
    public function process(mixed $data, Operation $operation, array $uriVariables = [], array $context = []): Jetons
    {
        $otp = $this->em->find(OtpCode::class, $data->otpId);

        if (null === $otp || null !== $otp->utiliseLe || $otp->expireLe < new \DateTimeImmutable()) {
            throw new UnprocessableEntityHttpException('Code expiré ou déjà utilisé. Demandez un nouveau code.');
        }
        if ($otp->tentatives >= OtpCode::MAX_TENTATIVES) {
            throw new TooManyRequestsHttpException(null, 'Trop de tentatives. Demandez un nouveau code.');
        }
        if (!$this->auth->otpCorrect($otp, $data->code)) {
            ++$otp->tentatives;
            $this->em->flush();
            $restants = OtpCode::MAX_TENTATIVES - $otp->tentatives;

            throw $restants > 0
                ? new UnprocessableEntityHttpException(\sprintf('Code invalide, %d essai(s) restant(s).', $restants))
                : new TooManyRequestsHttpException(null, 'Code invalide. Trop de tentatives : demandez un nouveau code.');
        }

        $otp->utiliseLe = new \DateTimeImmutable();

        $utilisateur = $this->em->getRepository(Utilisateur::class)->findOneBy(['telephone' => $otp->telephone]);
        $refus = match ($data->espace) {
            'admin' => RoleUtilisateur::Admin !== $utilisateur?->role
                ? "Ce numéro n'a pas de compte administrateur." : null,
            'representant' => !\in_array($utilisateur?->role, [RoleUtilisateur::Representant, RoleUtilisateur::Chauffeur], true)
                ? "Ce numéro n'a pas de compte représentant. Les comptes sont créés par le transporteur." : null,
            'marchand' => null !== $utilisateur && RoleUtilisateur::Marchand !== $utilisateur->role
                ? \sprintf('Ce numéro est enregistré comme %s : choisissez le bon espace.', $utilisateur->role->value) : null,
            default => null,
        };
        if (null !== $refus) {
            $this->em->flush();
            throw new AccessDeniedHttpException($refus);
        }
        $nouveauCompte = null === $utilisateur;
        if ($nouveauCompte) {
            $utilisateur = new Utilisateur();
            $utilisateur->telephone = $otp->telephone;
            $utilisateur->role = RoleUtilisateur::Marchand;
            $utilisateur->nomComplet = $data->nomComplet;
            $this->em->persist($utilisateur);
            $this->em->flush();
        } elseif (StatutCompte::Suspendu === $utilisateur->statutCompte) {
            $this->em->flush();
            throw new AccessDeniedHttpException('Compte suspendu. Contactez le support.');
        }

        $jetons = $this->auth->emettreJetons($utilisateur, $nouveauCompte);
        $this->em->flush();

        return $jetons;
    }
}

<?php

namespace App\Doctrine;

use ApiPlatform\Doctrine\Orm\Extension\QueryCollectionExtensionInterface;
use ApiPlatform\Doctrine\Orm\Util\QueryNameGeneratorInterface;
use ApiPlatform\Metadata\Operation;
use App\Entity\Demande;
use App\Entity\DocumentKyc;
use App\Entity\Notification;
use Doctrine\ORM\QueryBuilder;
use Symfony\Bundle\SecurityBundle\Security;

/**
 * Listes restreintes au propriétaire : un marchand ne voit que ses demandes,
 * chacun ne voit que ses notifications et documents KYC. Les admins voient tout.
 */
final class ProprietaireExtension implements QueryCollectionExtensionInterface
{
    /** Classe => [champ propriétaire, rôle concerné (null = tout le monde sauf admin)] */
    private const PROPRIETAIRES = [
        Demande::class => ['marchand', 'ROLE_MARCHAND'],
        Notification::class => ['utilisateur', null],
        DocumentKyc::class => ['utilisateur', null],
    ];

    public function __construct(private readonly Security $security)
    {
    }

    public function applyToCollection(QueryBuilder $queryBuilder, QueryNameGeneratorInterface $queryNameGenerator, string $resourceClass, ?Operation $operation = null, array $context = []): void
    {
        [$champ, $role] = self::PROPRIETAIRES[$resourceClass] ?? [null, null];
        if (null === $champ || $this->security->isGranted('ROLE_ADMIN')) {
            return;
        }
        if (null !== $role && !$this->security->isGranted($role)) {
            return;
        }

        $alias = $queryBuilder->getRootAliases()[0];
        $parametre = $queryNameGenerator->generateParameterName('proprietaire');
        $queryBuilder->andWhere("$alias.$champ = :$parametre")->setParameter($parametre, $this->security->getUser());
    }
}

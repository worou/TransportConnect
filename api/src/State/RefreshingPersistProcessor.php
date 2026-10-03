<?php

namespace App\State;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProcessorInterface;
use Doctrine\Persistence\ManagerRegistry;
use Symfony\Component\DependencyInjection\Attribute\AsDecorator;
use Symfony\Component\DependencyInjection\Attribute\AutowireDecorated;

/**
 * Les triggers PostgreSQL modifient des lignes au moment de l'écriture (numéro de demande, séquestre,
 * statuts synchronisés…). On relit l'entité après l'écriture pour que la réponse reflète la base.
 */
#[AsDecorator('api_platform.doctrine.orm.state.persist_processor')]
final class RefreshingPersistProcessor implements ProcessorInterface
{
    public function __construct(
        #[AutowireDecorated] private readonly ProcessorInterface $inner,
        private readonly ManagerRegistry $registry,
    ) {
    }

    public function process(mixed $data, Operation $operation, array $uriVariables = [], array $context = []): mixed
    {
        $result = $this->inner->process($data, $operation, $uriVariables, $context);

        if (\is_object($result) && ($manager = $this->registry->getManagerForClass($result::class)) && $manager->contains($result)) {
            $manager->refresh($result);
        }

        return $result;
    }
}

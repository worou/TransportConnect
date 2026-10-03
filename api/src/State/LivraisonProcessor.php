<?php

namespace App\State;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\Metadata\Post;
use ApiPlatform\State\ProcessorInterface;
use App\Entity\Livraison;
use App\Enum\StatutLivraison;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

/**
 * Code de réception : haché à la création, puis vérifié lors du passage au statut « livre ».
 */
final class LivraisonProcessor implements ProcessorInterface
{
    public function __construct(
        #[Autowire(service: 'api_platform.doctrine.orm.state.persist_processor')]
        private readonly ProcessorInterface $persistProcessor,
    ) {
    }

    /** @param Livraison $data */
    public function process(mixed $data, Operation $operation, array $uriVariables = [], array $context = []): Livraison
    {
        $code = $data->codeReception;
        $data->codeReception = null;

        if ($operation instanceof Post) {
            if (null === $code) {
                throw new UnprocessableEntityHttpException('code_reception : code à 4 chiffres obligatoire à la création de la livraison.');
            }
            $data->codeOtpHash = hash('sha256', $code);
        } elseif (StatutLivraison::Livre === $data->statut && StatutLivraison::Livre !== $context['previous_data']?->statut) {
            if (null === $code || !hash_equals($data->codeOtpHash, hash('sha256', $code))) {
                throw new UnprocessableEntityHttpException('Code de réception invalide.');
            }
            $data->dateLivraison = new \DateTimeImmutable();
        }

        return $this->persistProcessor->process($data, $operation, $uriVariables, $context);
    }
}

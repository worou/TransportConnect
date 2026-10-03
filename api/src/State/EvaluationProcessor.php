<?php

namespace App\State;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\Metadata\Post;
use ApiPlatform\State\ProcessorInterface;
use App\Entity\Evaluation;
use App\Enum\StatutDemande;
use Symfony\Component\DependencyInjection\Attribute\Autowire;

/**
 * Avance la demande : mission acceptée → REPRESENTANT_ASSIGNE, check-in sur place → EN_EVALUATION.
 */
final class EvaluationProcessor implements ProcessorInterface
{
    public function __construct(
        #[Autowire(service: 'api_platform.doctrine.orm.state.persist_processor')]
        private readonly ProcessorInterface $persistProcessor,
    ) {
    }

    /** @param Evaluation $data */
    public function process(mixed $data, Operation $operation, array $uriVariables = [], array $context = []): Evaluation
    {
        $demande = $data->demande;

        if ($operation instanceof Post && StatutDemande::EnAttente === $demande->statut) {
            $demande->statut = StatutDemande::RepresentantAssigne;
        }
        if (null !== $data->dateCheckin && StatutDemande::RepresentantAssigne === $demande->statut) {
            $demande->statut = StatutDemande::EnEvaluation;
        }

        return $this->persistProcessor->process($data, $operation, $uriVariables, $context);
    }
}

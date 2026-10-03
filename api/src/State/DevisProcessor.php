<?php

namespace App\State;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\Metadata\Post;
use ApiPlatform\State\ProcessorInterface;
use App\Entity\Devis;
use App\Enum\StatutDemande;
use App\Enum\StatutDevis;
use Doctrine\DBAL\Connection;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\HttpKernel\Exception\UnprocessableEntityHttpException;

/**
 * Création d'un devis : calcule le prix suggéré avec la grille tarifaire (fonction SQL calculer_prix_suggere),
 * propose ce prix par défaut et passe la demande en PRIX_PROPOSE.
 */
final class DevisProcessor implements ProcessorInterface
{
    private const STATUTS_AVANT_DEVIS = [StatutDemande::EnAttente, StatutDemande::RepresentantAssigne, StatutDemande::EnEvaluation];

    public function __construct(
        #[Autowire(service: 'api_platform.doctrine.orm.state.persist_processor')]
        private readonly ProcessorInterface $persistProcessor,
        private readonly Connection $connection,
    ) {
    }

    /** @param Devis $data */
    public function process(mixed $data, Operation $operation, array $uriVariables = [], array $context = []): Devis
    {
        if ($operation instanceof Post) {
            $evaluation = $data->evaluation;
            $demande = $evaluation->demande;
            $poids = $evaluation->poidsReel ?? $demande->poidsEstime;

            if (null === $demande->distanceKm || null === $poids) {
                throw new UnprocessableEntityHttpException('Distance de la demande et poids (réel ou estimé) requis pour calculer le prix.');
            }

            $data->prixSuggere = (int) $this->connection->fetchOne(
                'SELECT transconnect.calculer_prix_suggere(?, ?, ?, ?::transconnect.type_marchandise, ?::transconnect.niveau_urgence)',
                [$data->grille->id->toRfc4122(), $demande->distanceKm, $poids, $demande->typeMarchandise->value, $demande->urgence->value],
            );
            $data->prixPropose ??= $data->prixSuggere;

            if (\in_array($demande->statut, self::STATUTS_AVANT_DEVIS, true)) {
                $demande->statut = StatutDemande::PrixPropose;
            }
        }

        if (!$operation instanceof Post && StatutDevis::Refuse === $data->statut
            && StatutDevis::Refuse !== ($context['previous_data'] ?? null)?->statut) {
            // Refus du marchand : la demande est remise à disposition d'un autre transporteur
            $data->evaluation->demande->statut = StatutDemande::EnAttente;
        }

        return $this->persistProcessor->process($data, $operation, $uriVariables, $context);
    }
}

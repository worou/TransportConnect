<?php

namespace App\State\Admin;

use ApiPlatform\Metadata\Operation;
use ApiPlatform\State\ProviderInterface;
use App\ApiResource\Admin\TableauDeBord;
use Doctrine\DBAL\Connection;
use Symfony\Component\HttpFoundation\RequestStack;

final class TableauDeBordProvider implements ProviderInterface
{
    private const PERIODES = [7, 30, 365];

    public function __construct(
        private readonly Connection $connection,
        private readonly RequestStack $requestStack,
    ) {
    }

    public function provide(Operation $operation, array $uriVariables = [], array $context = []): TableauDeBord
    {
        $jours = (int) $this->requestStack->getCurrentRequest()?->query->get('periode', 30);
        if (!\in_array($jours, self::PERIODES, true)) {
            $jours = 30;
        }
        $p = ['j' => $jours];

        $t = new TableauDeBord();
        $t->periode = $jours;

        // Fenêtre courante : [now - j, now[ ; fenêtre précédente : [now - 2j, now - j[
        $courant = "now() - make_interval(days => :j)";
        $precedent = "now() - make_interval(days => 2 * :j)";

        $demandes = $this->connection->fetchAssociative(
            "SELECT count(*) FILTER (WHERE created_at >= $courant) AS cour,
                    count(*) FILTER (WHERE created_at >= $precedent AND created_at < $courant) AS prec
               FROM transconnect.demande", $p);
        $t->demandes = (int) $demandes['cour'];
        $t->demandesEvolutionPct = self::evolution($demandes['cour'], $demandes['prec']);

        $ca = $this->connection->fetchAssociative(
            "SELECT coalesce(sum(montant) FILTER (WHERE date_paiement >= $courant), 0) AS cour,
                    coalesce(sum(montant) FILTER (WHERE date_paiement >= $precedent AND date_paiement < $courant), 0) AS prec,
                    coalesce(sum(montant_commission) FILTER (WHERE date_paiement >= $courant), 0) AS commissions
               FROM transconnect.paiement WHERE statut = 'reussi'", $p);
        $t->chiffreAffaires = (int) $ca['cour'];
        $t->chiffreAffairesEvolutionPct = self::evolution($ca['cour'], $ca['prec']);
        $t->commissions = (int) $ca['commissions'];

        $acteurs = $this->connection->fetchAssociative(
            "SELECT (SELECT count(*) FROM transconnect.transporteur WHERE statut = 'actif') AS transporteurs_actifs,
                    (SELECT count(*) FROM transconnect.transporteur WHERE created_at >= $courant) AS transporteurs_nouveaux,
                    (SELECT count(*) FROM transconnect.transporteur WHERE statut = 'en_attente_validation') AS transporteurs_en_attente,
                    (SELECT count(*) FROM transconnect.utilisateur WHERE role = 'marchand') AS marchands,
                    (SELECT count(*) FROM transconnect.utilisateur WHERE role = 'marchand' AND date_inscription >= $courant) AS marchands_nouveaux,
                    (SELECT count(*) FROM transconnect.utilisateur WHERE statut_compte = 'en_attente_validation') AS comptes_en_attente,
                    (SELECT count(*) FROM transconnect.document_kyc WHERE statut_verification = 'en_attente') AS kyc_en_attente,
                    (SELECT count(*) FROM transconnect.litige WHERE statut <> 'resolu') AS litiges_ouverts,
                    (SELECT count(*) FROM transconnect.ville WHERE est_couverte) AS villes_couvertes", $p);
        $t->transporteursActifs = (int) $acteurs['transporteurs_actifs'];
        $t->transporteursNouveaux = (int) $acteurs['transporteurs_nouveaux'];
        $t->transporteursEnAttente = (int) $acteurs['transporteurs_en_attente'];
        $t->marchandsInscrits = (int) $acteurs['marchands'];
        $t->marchandsNouveaux = (int) $acteurs['marchands_nouveaux'];
        $t->comptesEnAttente = (int) $acteurs['comptes_en_attente'];
        $t->kycEnAttente = (int) $acteurs['kyc_en_attente'];
        $t->litigesOuverts = (int) $acteurs['litiges_ouverts'];
        $t->villesCouvertes = (int) $acteurs['villes_couvertes'];

        $conversion = $this->connection->fetchOne(
            "SELECT round(100.0 * count(*) FILTER (WHERE statut = 'accepte') / nullif(count(*), 0), 1)
               FROM transconnect.devis WHERE date_emission >= $courant", $p);
        $t->tauxConversionPct = null === $conversion ? null : (float) $conversion;

        $delai = $this->connection->fetchOne(
            "SELECT round(extract(epoch FROM avg(e.date_soumission - d.created_at)) / 60)
               FROM transconnect.evaluation e JOIN transconnect.demande d ON d.id_demande = e.id_demande
              WHERE e.date_soumission >= $courant", $p);
        $t->delaiMoyenEvaluationMinutes = null === $delai ? null : (int) $delai;

        $litige = $this->connection->fetchOne(
            'SELECT round(100.0 * (SELECT count(*) FROM transconnect.litige) / nullif(count(*), 0), 2) FROM transconnect.livraison');
        $t->tauxLitigePct = null === $litige ? null : (float) $litige;

        $t->tauxCommissionPct = (float) $this->connection->fetchOne(
            "SELECT trim(both '''' from split_part(column_default, '::', 1))
               FROM information_schema.columns
              WHERE table_schema = 'transconnect' AND table_name = 'paiement' AND column_name = 'taux_commission'");

        $t->zonesActives = array_map(
            static fn (array $r) => ['ville' => $r['nom_ville'], 'nb_demandes' => (int) $r['nb']],
            $this->connection->fetchAllAssociative(
                "SELECT v.nom_ville, count(*) AS nb
                   FROM transconnect.demande d JOIN transconnect.ville v ON v.id_ville = d.id_ville_depart
                  WHERE d.created_at >= $courant
                  GROUP BY v.nom_ville ORDER BY nb DESC, v.nom_ville LIMIT 5", $p),
        );
        $t->demandesParStatut = array_map('intval', $this->connection->fetchAllKeyValue(
            'SELECT statut::text, count(*) FROM transconnect.demande GROUP BY statut ORDER BY statut'));
        $t->demandesParJour = array_map(
            static fn (array $r) => ['jour' => $r['jour'], 'nb_demandes' => (int) $r['nb']],
            $this->connection->fetchAllAssociative(
                "SELECT to_char(j, 'YYYY-MM-DD') AS jour, count(d.id_demande) AS nb
                   FROM generate_series(current_date - 13, current_date, interval '1 day') AS j
                   LEFT JOIN transconnect.demande d ON d.created_at::date = j::date
                  GROUP BY j ORDER BY j"),
        );

        return $t;
    }

    private static function evolution(int|string $courant, int|string $precedent): ?float
    {
        return 0 === (int) $precedent ? null : round(100 * ((int) $courant - (int) $precedent) / (int) $precedent, 1);
    }
}

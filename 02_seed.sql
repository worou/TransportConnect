-- =====================================================================
--  TransConnect - Données de démonstration (scénarios des maquettes)
--  Exécution : psql -d transconnect -f 02_seed.sql
-- =====================================================================

SET client_encoding = 'UTF8';
BEGIN;
SET search_path TO transconnect, public;

-- Villes couvertes (Bénin)
INSERT INTO ville (nom_ville, latitude, longitude) VALUES
 ('Cotonou', 6.365400, 2.418300), ('Porto-Novo', 6.496900, 2.628900), ('Abomey-Calavi', 6.448500, 2.355700),
 ('Parakou', 9.337200, 2.630300), ('Bohicon', 7.178200, 2.066700), ('Abomey', 7.182900, 1.991200),
 ('Dassa-Zoumè', 7.750000, 2.183300), ('Natitingou', 10.304200, 1.379600), ('Kandi', 11.134200, 2.938600),
 ('Djougou', 9.708500, 1.666000);

-- Transporteur, flotte et grille
INSERT INTO transporteur (id_transporteur, raison_sociale, num_rccm, telephone, abonnement, statut) VALUES
 ('10000000-0000-0000-0000-000000000001', 'TransBénin Express', 'RB/COT/24 B 1234', '+22921300000', 'premium', 'actif');

INSERT INTO vehicule (id_vehicule, id_transporteur, immatriculation, type_vehicule, capacite_kg, capacite_m3, gps_actif) VALUES
 ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'AB 4521 RB', 'Camion 5 T', 5000, 25, TRUE),
 ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'BC 1180 RB', 'Fourgon 1,5 T', 1500, 9, FALSE);

INSERT INTO grille_tarifaire (id_grille, id_transporteur, prix_base, tarif_km, tarif_kg, supplement_express, date_effet) VALUES
 ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 5000, 50, 13.80, 5000, '2026-01-01');

-- Utilisateurs
INSERT INTO utilisateur (id_utilisateur, telephone, nom_complet, role, id_ville_residence, id_transporteur, type_activite, disponibilite, statut_compte) VALUES
 ('40000000-0000-0000-0000-000000000001', '+22990000001', 'Admin TransportConnect', 'admin',        1, NULL, NULL, NULL, 'actif'),
 ('40000000-0000-0000-0000-000000000002', '+22997123456', 'Ali Dossou',         'marchand',     1, NULL, 'commerce_general', NULL, 'actif'),
 ('40000000-0000-0000-0000-000000000003', '+22996112233', 'Fatou Bello',        'marchand',     1, NULL, 'textile', NULL, 'actif'),
 ('40000000-0000-0000-0000-000000000004', '+22994556677', 'Koffi Agbo',         'marchand',     3, NULL, 'alimentaire', NULL, 'actif'),
 ('40000000-0000-0000-0000-000000000005', '+22996000001', 'Jean Kpadonou',      'representant', 1, '10000000-0000-0000-0000-000000000001', NULL, 'disponible', 'actif'),
 ('40000000-0000-0000-0000-000000000006', '+22995000002', 'Moussa Sanni',       'chauffeur',    1, '10000000-0000-0000-0000-000000000001', NULL, 'occupe', 'actif');

INSERT INTO zone_intervention (id_utilisateur, id_ville) VALUES
 ('40000000-0000-0000-0000-000000000005', 1), ('40000000-0000-0000-0000-000000000005', 3);

INSERT INTO document_kyc (id_utilisateur, type_document, url_fichier, statut_verification, verifie_par, verifie_le) VALUES
 ('40000000-0000-0000-0000-000000000002', 'cni_recto', 's3://kyc/ali/cni_recto.jpg', 'valide', '40000000-0000-0000-0000-000000000001', now()),
 ('40000000-0000-0000-0000-000000000005', 'badge',     's3://kyc/jean/badge.jpg',    'valide', '40000000-0000-0000-0000-000000000001', now()),
 ('40000000-0000-0000-0000-000000000005', 'contrat',   's3://kyc/jean/contrat.pdf',  'valide', '40000000-0000-0000-0000-000000000001', now()),
 ('40000000-0000-0000-0000-000000000003', 'cni_recto', 's3://kyc/fatou/cni_recto.jpg', 'en_attente', NULL, NULL);

-- ---------------------------------------------------------------------
-- Scénario 1 : TC-2026-00123 Cotonou → Parakou, cycle complet jusqu'à LIVRE
-- ---------------------------------------------------------------------
SELECT setval('demande_numero_seq', 122);

INSERT INTO demande (id_demande, id_marchand, id_ville_depart, id_ville_arrivee, adresse_depart, adresse_arrivee,
                     type_marchandise, description, poids_estime, volume_estime, nb_colis, date_enlevement, urgence,
                     contact_nom, contact_telephone, distance_km)
VALUES ('50000000-0000-0000-0000-000000000123', '40000000-0000-0000-0000-000000000002', 1, 4,
        'Akpakpa, rue 12', 'Centre-ville', 'standard', '20 sacs de riz de 50 kg, bien fermés',
        1000, 5, 20, '2026-10-05', 'express', 'Ali Dossou', '+22997123456', 410);

INSERT INTO photo (url, contexte, id_demande) VALUES
 ('s3://photos/TC-2026-00123/demande-1.jpg', 'demande', '50000000-0000-0000-0000-000000000123');

-- Le représentant accepte la mission et se rend sur place
INSERT INTO evaluation (id_evaluation, id_demande, id_representant)
VALUES ('60000000-0000-0000-0000-000000000123', '50000000-0000-0000-0000-000000000123', '40000000-0000-0000-0000-000000000005');
UPDATE demande SET statut = 'REPRESENTANT_ASSIGNE' WHERE id_demande = '50000000-0000-0000-0000-000000000123';

UPDATE evaluation SET date_checkin = now(), lat_checkin = 6.362100, lng_checkin = 2.447800, distance_checkin_m = 32,
       poids_reel = 1050, volume_reel = 5.2, etat_emballage = 'moyen', contraintes = '2 sacs légèrement déchirés, à protéger'
 WHERE id_evaluation = '60000000-0000-0000-0000-000000000123';
UPDATE demande SET statut = 'EN_EVALUATION' WHERE id_demande = '50000000-0000-0000-0000-000000000123';

INSERT INTO photo (url, contexte, id_evaluation) VALUES
 ('s3://photos/TC-2026-00123/eval-1.jpg', 'evaluation', '60000000-0000-0000-0000-000000000123'),
 ('s3://photos/TC-2026-00123/eval-2.jpg', 'evaluation', '60000000-0000-0000-0000-000000000123');
UPDATE evaluation SET date_soumission = now() WHERE id_evaluation = '60000000-0000-0000-0000-000000000123';

-- Devis : prix suggéré calculé par la grille (45 000 FCFA), non ajusté
INSERT INTO devis (id_devis, id_evaluation, id_grille, prix_suggere, prix_propose, delai_jours, type_vehicule)
SELECT '70000000-0000-0000-0000-000000000123', '60000000-0000-0000-0000-000000000123', '30000000-0000-0000-0000-000000000001',
       p, p, 2, 'Camion 5 T'
  FROM calculer_prix_suggere('30000000-0000-0000-0000-000000000001', 410, 1050, 'standard', 'express') AS p;
UPDATE demande SET statut = 'PRIX_PROPOSE' WHERE id_demande = '50000000-0000-0000-0000-000000000123';
UPDATE demande SET statut = 'PAIEMENT_EN_ATTENTE' WHERE id_demande = '50000000-0000-0000-0000-000000000123';

-- Première tentative échouée, puis paiement Mobile Money réussi (trigger → séquestre bloqué, demande PAYE)
INSERT INTO paiement (id_devis, montant, moyen, operateur, numero_payeur, reference_psp, statut, motif_echec) VALUES
 ('70000000-0000-0000-0000-000000000123', 45000, 'mobile_money', 'MTN', '+22997123456', 'PAY-8F3K20', 'echoue', 'Solde insuffisant');
INSERT INTO paiement (id_paiement, id_devis, montant, moyen, operateur, numero_payeur, reference_psp, statut, url_recu) VALUES
 ('80000000-0000-0000-0000-000000000123', '70000000-0000-0000-0000-000000000123', 45000, 'mobile_money', 'MTN', '+22997123456',
  'PAY-8F3K21', 'reussi', 's3://recus/TC-2026-00123.pdf');

-- Livraison (code de réception 4829, stocké haché)
INSERT INTO livraison (id_livraison, id_demande, id_chauffeur, id_vehicule, code_otp_hash, code_clair, date_arrivee_estimee)
VALUES ('90000000-0000-0000-0000-000000000123', '50000000-0000-0000-0000-000000000123',
        '40000000-0000-0000-0000-000000000006', '20000000-0000-0000-0000-000000000001',
        '1ec08285a725fe5e0141cc5cc8d493b342a3d12c75ae73b3acd393bc3b7d5d3a', '4829', '2026-10-07');   -- SHA-256 de « 4829 »

UPDATE livraison SET statut = 'enleve', date_enlevement_reel = now() WHERE id_livraison = '90000000-0000-0000-0000-000000000123';
INSERT INTO position_gps (id_livraison, latitude, longitude, vitesse_kmh) VALUES
 ('90000000-0000-0000-0000-000000000123', 6.365400, 2.418300, 0),
 ('90000000-0000-0000-0000-000000000123', 7.178200, 2.066700, 72),
 ('90000000-0000-0000-0000-000000000123', 7.750000, 2.183300, 68);
UPDATE livraison SET statut = 'en_transit' WHERE id_livraison = '90000000-0000-0000-0000-000000000123';
INSERT INTO incident (id_livraison, type_incident, description, resolu_le) VALUES
 ('90000000-0000-0000-0000-000000000123', 'retard', 'Contrôle routier à Dassa-Zoumè (45 min)', now());

-- Remise contre code OTP, preuve photo, libération des fonds
UPDATE livraison SET statut = 'livre', date_livraison = now(), signature_url = 's3://signatures/TC-2026-00123.png'
 WHERE id_livraison = '90000000-0000-0000-0000-000000000123';
INSERT INTO photo (url, contexte, id_livraison) VALUES
 ('s3://photos/TC-2026-00123/remise.jpg', 'livraison', '90000000-0000-0000-0000-000000000123');
UPDATE paiement SET statut_sequestre = 'libere' WHERE id_paiement = '80000000-0000-0000-0000-000000000123';

-- Notation réciproque
INSERT INTO avis (id_livraison, type_auteur, note, commentaire) VALUES
 ('90000000-0000-0000-0000-000000000123', 'marchand',     5, 'Livraison rapide, chauffeur joignable.'),
 ('90000000-0000-0000-0000-000000000123', 'transporteur', 5, 'Marchandise prête à l''heure.');

-- ---------------------------------------------------------------------
-- Scénario 2 : TC-2026-00124 Cotonou → Bohicon, devis en négociation
-- ---------------------------------------------------------------------
INSERT INTO demande (id_demande, id_marchand, id_ville_depart, id_ville_arrivee, adresse_depart, adresse_arrivee,
                     type_marchandise, description, poids_estime, date_enlevement, urgence, distance_km)
VALUES ('50000000-0000-0000-0000-000000000124', '40000000-0000-0000-0000-000000000002', 1, 5,
        'Dantokpa, porte 3', 'Marché central', 'alimentaire', '30 cartons d''huile', 600, '2026-10-06', 'normale', 145);
INSERT INTO evaluation (id_evaluation, id_demande, id_representant, date_checkin, lat_checkin, lng_checkin,
                        distance_checkin_m, poids_reel, volume_reel, etat_emballage)
VALUES ('60000000-0000-0000-0000-000000000124', '50000000-0000-0000-0000-000000000124', '40000000-0000-0000-0000-000000000005',
        now(), 6.371000, 2.432000, 18, 620, 3.0, 'bon');
INSERT INTO devis (id_devis, id_evaluation, id_grille, prix_suggere, prix_propose, justification, delai_jours, type_vehicule)
SELECT '70000000-0000-0000-0000-000000000124', '60000000-0000-0000-0000-000000000124', '30000000-0000-0000-0000-000000000001',
       p, p + 2000, 'Accès difficile au point d''enlèvement (ruelle étroite).', 1, 'Fourgon 1,5 T'
  FROM calculer_prix_suggere('30000000-0000-0000-0000-000000000001', 145, 620, 'alimentaire', 'normale') AS p;   -- 22 900 + 2 000
UPDATE demande SET statut = 'PRIX_PROPOSE' WHERE id_demande = '50000000-0000-0000-0000-000000000124';
INSERT INTO message_negociation (id_devis, emetteur, prix_contre_offre, message) VALUES
 ('70000000-0000-0000-0000-000000000124', 'marchand',     20000, 'Je peux livrer les cartons en bord de route.'),
 ('70000000-0000-0000-0000-000000000124', 'representant', 21500, 'D''accord à 21 500 F si c''est en bord de route.');
UPDATE demande SET statut = 'EN_NEGOCIATION' WHERE id_demande = '50000000-0000-0000-0000-000000000124';

-- ---------------------------------------------------------------------
-- Scénarios 3 et 4 : missions en attente dans la zone de Jean
-- ---------------------------------------------------------------------
INSERT INTO demande (id_marchand, id_ville_depart, id_ville_arrivee, adresse_depart, adresse_arrivee,
                     type_marchandise, description, poids_estime, date_enlevement, urgence, distance_km) VALUES
 ('40000000-0000-0000-0000-000000000003', 1, 5, 'Dantokpa', 'Quartier Zakpota', 'standard', 'Ballots de textile', 300, '2026-10-06', 'normale', 140),
 ('40000000-0000-0000-0000-000000000004', 3, 9, 'Calavi Kpota', 'Marché de Kandi', 'alimentaire', 'Sacs de maïs et de gari', 800, '2026-10-07', 'normale', 640);

-- Notifications
INSERT INTO notification (id_utilisateur, canal, titre, contenu, lien_cible) VALUES
 ('40000000-0000-0000-0000-000000000002', 'push', 'Prix proposé', 'TransBénin Express propose 23 000 FCFA pour TC-2026-00124.', 'demande/TC-2026-00124'),
 ('40000000-0000-0000-0000-000000000005', 'push', 'Nouvelle mission', 'Nouvelle demande à Cotonou : textile 300 kg.', 'missions');

COMMIT;

-- =====================================================================
--  TransConnect - Schéma PostgreSQL (MLD issu du MCD)
--  Cible : PostgreSQL 14+   |   Monnaie : XOF (FCFA, montants entiers)
--  Exécution : psql -d transconnect -f 01_schema.sql
-- =====================================================================

SET client_encoding = 'UTF8';
BEGIN;

DROP SCHEMA IF EXISTS transconnect CASCADE;
CREATE SCHEMA transconnect;
SET search_path TO transconnect, public;

-- ---------------------------------------------------------------------
-- 1. Types énumérés
-- ---------------------------------------------------------------------
CREATE TYPE role_utilisateur    AS ENUM ('marchand', 'representant', 'chauffeur', 'admin');
CREATE TYPE statut_compte       AS ENUM ('en_attente_validation', 'actif', 'suspendu');
CREATE TYPE disponibilite       AS ENUM ('disponible', 'occupe', 'hors_ligne');
CREATE TYPE type_document       AS ENUM ('cni_recto', 'cni_verso', 'selfie', 'registre_commerce', 'badge', 'contrat');
CREATE TYPE statut_verification AS ENUM ('en_attente', 'valide', 'rejete');
CREATE TYPE canal_notification  AS ENUM ('push', 'sms', 'in_app', 'email');
CREATE TYPE type_marchandise    AS ENUM ('standard', 'alimentaire', 'fragile', 'dangereuse', 'betail');
CREATE TYPE niveau_urgence      AS ENUM ('normale', 'express');
CREATE TYPE statut_demande      AS ENUM ('EN_ATTENTE', 'REPRESENTANT_ASSIGNE', 'EN_EVALUATION', 'PRIX_PROPOSE',
                                         'EN_NEGOCIATION', 'PAIEMENT_EN_ATTENTE', 'PAYE', 'EN_TRANSIT',
                                         'LIVRE', 'ANNULE', 'LITIGE');
CREATE TYPE etat_emballage      AS ENUM ('bon', 'moyen', 'mauvais');
CREATE TYPE statut_devis        AS ENUM ('propose', 'en_negociation', 'accepte', 'refuse', 'expire');
CREATE TYPE emetteur_message    AS ENUM ('marchand', 'representant');
CREATE TYPE moyen_paiement      AS ENUM ('mobile_money', 'carte', 'virement');
CREATE TYPE statut_paiement     AS ENUM ('initie', 'en_cours', 'reussi', 'echoue', 'rembourse');
CREATE TYPE statut_sequestre    AS ENUM ('bloque', 'libere', 'rembourse_total', 'rembourse_partiel');
CREATE TYPE statut_livraison    AS ENUM ('pret_enlevement', 'enleve', 'en_transit', 'incident', 'arrive', 'livre');
CREATE TYPE contexte_photo      AS ENUM ('demande', 'evaluation', 'livraison');
CREATE TYPE type_incident       AS ENUM ('panne', 'accident', 'retard', 'autre');
CREATE TYPE motif_litige        AS ENUM ('colis_endommage', 'colis_manquant', 'non_livre', 'autre');
CREATE TYPE statut_litige       AS ENUM ('ouvert', 'en_cours', 'resolu');
CREATE TYPE decision_litige     AS ENUM ('remboursement_total', 'remboursement_partiel', 'liberation_transporteur');
CREATE TYPE type_auteur_avis    AS ENUM ('marchand', 'transporteur');

-- ---------------------------------------------------------------------
-- 2. Référentiel et acteurs
-- ---------------------------------------------------------------------
CREATE TABLE ville (
    id_ville      SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom_ville     VARCHAR(80)  NOT NULL,
    pays          CHAR(2)      NOT NULL DEFAULT 'BJ',          -- ISO 3166-1
    est_couverte  BOOLEAN      NOT NULL DEFAULT TRUE,
    latitude      NUMERIC(9,6),
    longitude     NUMERIC(9,6),
    UNIQUE (nom_ville, pays)
);

CREATE TABLE transporteur (
    id_transporteur UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    raison_sociale  VARCHAR(150) NOT NULL,
    num_rccm        VARCHAR(50)  NOT NULL UNIQUE,
    telephone       VARCHAR(20)  NOT NULL CHECK (telephone ~ '^\+[1-9][0-9]{7,14}$'),
    abonnement      VARCHAR(20)  NOT NULL DEFAULT 'gratuit' CHECK (abonnement IN ('gratuit', 'premium')),
    note_moyenne    NUMERIC(2,1) CHECK (note_moyenne BETWEEN 1 AND 5),
    nb_avis         INTEGER      NOT NULL DEFAULT 0,
    statut          statut_compte NOT NULL DEFAULT 'en_attente_validation',
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE utilisateur (
    id_utilisateur     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    telephone          VARCHAR(20)  NOT NULL UNIQUE CHECK (telephone ~ '^\+[1-9][0-9]{7,14}$'),
    nom_complet        VARCHAR(120),
    role               role_utilisateur NOT NULL,
    id_ville_residence SMALLINT REFERENCES ville(id_ville),
    id_transporteur    UUID REFERENCES transporteur(id_transporteur) ON DELETE RESTRICT,   -- Appartenir
    type_activite      VARCHAR(60),
    avatar_url         TEXT,
    statut_compte      statut_compte NOT NULL DEFAULT 'actif',
    disponibilite      disponibilite,
    note_moyenne       NUMERIC(2,1) CHECK (note_moyenne BETWEEN 1 AND 5),
    nb_avis            INTEGER      NOT NULL DEFAULT 0,
    date_inscription   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    -- Seuls représentants et chauffeurs appartiennent à un transporteur
    CONSTRAINT ck_utilisateur_transporteur
        CHECK ((role IN ('representant', 'chauffeur')) = (id_transporteur IS NOT NULL)),
    CONSTRAINT ck_utilisateur_disponibilite
        CHECK (disponibilite IS NULL OR role IN ('representant', 'chauffeur'))
);

CREATE TABLE refresh_token (
    id_token       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_utilisateur UUID NOT NULL REFERENCES utilisateur(id_utilisateur) ON DELETE CASCADE,
    token_hash     TEXT NOT NULL UNIQUE,
    expire_le      TIMESTAMPTZ NOT NULL,
    revoque_le     TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE otp_code (
    id_otp      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    telephone   VARCHAR(20) NOT NULL,
    code_hash   TEXT        NOT NULL,
    tentatives  SMALLINT    NOT NULL DEFAULT 0 CHECK (tentatives <= 3),
    expire_le   TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '5 minutes',
    utilise_le  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE document_kyc (                                                    -- Posséder
    id_document         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_utilisateur      UUID NOT NULL REFERENCES utilisateur(id_utilisateur) ON DELETE CASCADE,
    type_document       type_document NOT NULL,
    url_fichier         TEXT NOT NULL,
    statut_verification statut_verification NOT NULL DEFAULT 'en_attente',
    motif_rejet         TEXT,
    date_depot          TIMESTAMPTZ NOT NULL DEFAULT now(),
    verifie_par         UUID REFERENCES utilisateur(id_utilisateur),
    verifie_le          TIMESTAMPTZ
);

CREATE TABLE notification (                                                    -- Recevoir
    id_notification UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_utilisateur  UUID NOT NULL REFERENCES utilisateur(id_utilisateur) ON DELETE CASCADE,
    canal           canal_notification NOT NULL,
    titre           VARCHAR(120) NOT NULL,
    contenu         TEXT NOT NULL,
    lien_cible      TEXT,                                                      -- ex : demande/TC-2026-00123
    est_lue         BOOLEAN NOT NULL DEFAULT FALSE,
    date_envoi      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE vehicule (                                                        -- Disposer
    id_vehicule     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_transporteur UUID NOT NULL REFERENCES transporteur(id_transporteur) ON DELETE CASCADE,
    immatriculation VARCHAR(20) NOT NULL UNIQUE,
    type_vehicule   VARCHAR(40) NOT NULL,                                      -- ex : Camion 5 T
    capacite_kg     INTEGER NOT NULL CHECK (capacite_kg > 0),
    capacite_m3     NUMERIC(6,2) CHECK (capacite_m3 > 0),
    gps_actif       BOOLEAN NOT NULL DEFAULT FALSE,
    actif           BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE grille_tarifaire (                                                -- Définir
    id_grille          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_transporteur    UUID NOT NULL REFERENCES transporteur(id_transporteur) ON DELETE CASCADE,
    prix_base          INTEGER NOT NULL CHECK (prix_base >= 0),
    tarif_km           NUMERIC(10,2) NOT NULL CHECK (tarif_km >= 0),
    tarif_kg           NUMERIC(10,2) NOT NULL CHECK (tarif_kg >= 0),
    supplement_express INTEGER NOT NULL DEFAULT 0 CHECK (supplement_express >= 0),
    coef_type_marchandise JSONB NOT NULL DEFAULT
        '{"standard":1.0,"alimentaire":1.1,"fragile":1.3,"dangereuse":1.5,"betail":1.4}',
    date_effet         DATE NOT NULL DEFAULT CURRENT_DATE,
    actif              BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (id_transporteur, date_effet)
);

CREATE TABLE zone_intervention (                                               -- Couvrir (n,n)
    id_utilisateur UUID     NOT NULL REFERENCES utilisateur(id_utilisateur) ON DELETE CASCADE,
    id_ville       SMALLINT NOT NULL REFERENCES ville(id_ville),
    PRIMARY KEY (id_utilisateur, id_ville)
);

-- ---------------------------------------------------------------------
-- 3. Demande, évaluation, devis
-- ---------------------------------------------------------------------
CREATE SEQUENCE demande_numero_seq;

CREATE TABLE demande (
    id_demande        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero            VARCHAR(20) UNIQUE,                                      -- TC-AAAA-NNNNN (trigger)
    id_marchand       UUID NOT NULL REFERENCES utilisateur(id_utilisateur),    -- Créer
    id_ville_depart   SMALLINT NOT NULL REFERENCES ville(id_ville),            -- Partir de
    id_ville_arrivee  SMALLINT NOT NULL REFERENCES ville(id_ville),            -- Arriver à
    adresse_depart    VARCHAR(255) NOT NULL,
    adresse_arrivee   VARCHAR(255) NOT NULL,
    type_marchandise  type_marchandise NOT NULL,
    description       VARCHAR(500) NOT NULL,
    poids_estime      NUMERIC(10,2) CHECK (poids_estime > 0),
    volume_estime     NUMERIC(8,2)  CHECK (volume_estime > 0),
    nb_colis          INTEGER       CHECK (nb_colis > 0),
    date_enlevement   DATE NOT NULL,
    urgence           niveau_urgence NOT NULL DEFAULT 'normale',
    contact_nom       VARCHAR(120),
    contact_telephone VARCHAR(20),
    instructions      VARCHAR(500),
    distance_km       NUMERIC(7,1) CHECK (distance_km > 0),
    statut            statut_demande NOT NULL DEFAULT 'EN_ATTENTE',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_demande_villes   CHECK (id_ville_depart <> id_ville_arrivee),
    CONSTRAINT ck_demande_quantite CHECK (num_nonnulls(poids_estime, volume_estime, nb_colis) >= 1)
);

CREATE TABLE historique_statut (                                               -- Historiser
    id_historique   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_demande      UUID NOT NULL REFERENCES demande(id_demande) ON DELETE CASCADE,
    ancien_statut   statut_demande,
    nouveau_statut  statut_demande NOT NULL,
    date_changement TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE evaluation (
    id_evaluation     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_demande        UUID NOT NULL REFERENCES demande(id_demande) ON DELETE CASCADE,   -- Concerner
    id_representant   UUID NOT NULL REFERENCES utilisateur(id_utilisateur),            -- Effectuer
    date_acceptation  TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_checkin      TIMESTAMPTZ,
    lat_checkin       NUMERIC(9,6),
    lng_checkin       NUMERIC(9,6),
    distance_checkin_m INTEGER CHECK (distance_checkin_m >= 0),
    poids_reel        NUMERIC(10,2) CHECK (poids_reel > 0),
    volume_reel       NUMERIC(8,2)  CHECK (volume_reel > 0),
    etat_emballage    etat_emballage,
    contraintes       TEXT,
    date_soumission   TIMESTAMPTZ,
    -- Check-in GPS obligatoire dans un rayon de 100 m
    CONSTRAINT ck_evaluation_checkin
        CHECK (date_checkin IS NULL OR (lat_checkin IS NOT NULL AND lng_checkin IS NOT NULL
                                        AND distance_checkin_m <= 100))
);

CREATE TABLE devis (
    id_devis        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_evaluation   UUID NOT NULL UNIQUE REFERENCES evaluation(id_evaluation) ON DELETE CASCADE, -- Aboutir à
    id_grille       UUID NOT NULL REFERENCES grille_tarifaire(id_grille),                         -- Appliquer
    prix_suggere    INTEGER NOT NULL CHECK (prix_suggere > 0),
    prix_propose    INTEGER NOT NULL CHECK (prix_propose > 0),
    justification   TEXT,
    delai_jours     SMALLINT NOT NULL CHECK (delai_jours > 0),
    type_vehicule   VARCHAR(40),
    date_emission   TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_expiration TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '72 hours',
    statut          statut_devis NOT NULL DEFAULT 'propose',
    -- Ajustement manuel limité à ±20 %, justification obligatoire si modifié
    CONSTRAINT ck_devis_ajustement
        CHECK (prix_propose BETWEEN prix_suggere * 0.8 AND prix_suggere * 1.2),
    CONSTRAINT ck_devis_justification
        CHECK (prix_propose = prix_suggere OR length(trim(justification)) > 0)
);

CREATE TABLE message_negociation (                                             -- Négocier
    id_message        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_devis          UUID NOT NULL REFERENCES devis(id_devis) ON DELETE CASCADE,
    emetteur          emetteur_message NOT NULL,
    prix_contre_offre INTEGER CHECK (prix_contre_offre > 0),
    message           VARCHAR(200),
    date_envoi        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (prix_contre_offre IS NOT NULL OR message IS NOT NULL)
);

-- ---------------------------------------------------------------------
-- 4. Paiement
-- ---------------------------------------------------------------------
CREATE TABLE paiement (                                                        -- Régler
    id_paiement        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_devis           UUID NOT NULL REFERENCES devis(id_devis),
    montant            INTEGER NOT NULL CHECK (montant > 0),
    devise             CHAR(3) NOT NULL DEFAULT 'XOF',
    moyen              moyen_paiement NOT NULL,
    operateur          VARCHAR(30),                                            -- MTN, Moov, Wave, Orange…
    numero_payeur      VARCHAR(20),
    reference_psp      VARCHAR(100) UNIQUE,
    statut             statut_paiement NOT NULL DEFAULT 'initie',
    statut_sequestre   statut_sequestre,
    taux_commission    NUMERIC(4,2) NOT NULL DEFAULT 7.00 CHECK (taux_commission BETWEEN 0 AND 30),
    montant_commission INTEGER GENERATED ALWAYS AS (ROUND(montant * taux_commission / 100)::INTEGER) STORED,
    url_recu           TEXT,
    motif_echec        TEXT,
    date_paiement      TIMESTAMPTZ,
    date_liberation    TIMESTAMPTZ,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_paiement_mobile CHECK (moyen <> 'mobile_money' OR (operateur IS NOT NULL AND numero_payeur IS NOT NULL)),
    CONSTRAINT ck_paiement_sequestre CHECK (statut_sequestre IS NULL OR statut IN ('reussi', 'rembourse'))
);
-- Une seule tentative réussie par devis
CREATE UNIQUE INDEX ux_paiement_reussi ON paiement(id_devis) WHERE statut = 'reussi';

-- ---------------------------------------------------------------------
-- 5. Transport et livraison
-- ---------------------------------------------------------------------
CREATE TABLE livraison (                                                       -- Donner lieu à
    id_livraison        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_demande          UUID NOT NULL UNIQUE REFERENCES demande(id_demande),
    id_chauffeur        UUID REFERENCES utilisateur(id_utilisateur),           -- Exécuter (MVP+1)
    id_vehicule         UUID REFERENCES vehicule(id_vehicule),                 -- Utiliser
    code_otp_hash       TEXT NOT NULL,                                         -- code de réception, stocké haché
    statut              statut_livraison NOT NULL DEFAULT 'pret_enlevement',
    date_enlevement_reel TIMESTAMPTZ,
    date_arrivee_estimee DATE,
    date_livraison      TIMESTAMPTZ,
    signature_url       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (statut <> 'livre' OR date_livraison IS NOT NULL)
);

CREATE TABLE position_gps (                                                    -- Tracer
    id_position  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_livraison UUID NOT NULL REFERENCES livraison(id_livraison) ON DELETE CASCADE,
    latitude     NUMERIC(9,6) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude    NUMERIC(9,6) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    vitesse_kmh  NUMERIC(5,1),
    horodatage   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE incident (                                                        -- Signaler
    id_incident      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_livraison     UUID NOT NULL REFERENCES livraison(id_livraison) ON DELETE CASCADE,
    type_incident    type_incident NOT NULL,
    description      TEXT NOT NULL,
    date_signalement TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolu_le        TIMESTAMPTZ
);

-- PHOTO : Illustrer / Documenter / Prouver (une seule FK renseignée selon le contexte)
CREATE TABLE photo (
    id_photo      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    url           TEXT NOT NULL,
    contexte      contexte_photo NOT NULL,
    id_demande    UUID REFERENCES demande(id_demande)       ON DELETE CASCADE,
    id_evaluation UUID REFERENCES evaluation(id_evaluation) ON DELETE CASCADE,
    id_livraison  UUID REFERENCES livraison(id_livraison)   ON DELETE CASCADE,
    date_prise    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_photo_contexte CHECK (
        num_nonnulls(id_demande, id_evaluation, id_livraison) = 1 AND
        ((contexte = 'demande'    AND id_demande    IS NOT NULL) OR
         (contexte = 'evaluation' AND id_evaluation IS NOT NULL) OR
         (contexte = 'livraison'  AND id_livraison  IS NOT NULL)))
);

-- ---------------------------------------------------------------------
-- 6. Litiges et avis
-- ---------------------------------------------------------------------
CREATE TABLE litige (
    id_litige         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_demande        UUID NOT NULL UNIQUE REFERENCES demande(id_demande),     -- Porter sur
    id_ouvreur        UUID NOT NULL REFERENCES utilisateur(id_utilisateur),    -- Ouvrir
    id_admin          UUID REFERENCES utilisateur(id_utilisateur),             -- Arbitrer
    motif             motif_litige NOT NULL,
    description       TEXT NOT NULL,
    statut            statut_litige NOT NULL DEFAULT 'ouvert',
    decision          decision_litige,
    montant_rembourse INTEGER CHECK (montant_rembourse >= 0),
    date_ouverture    TIMESTAMPTZ NOT NULL DEFAULT now(),
    date_resolution   TIMESTAMPTZ,
    CONSTRAINT ck_litige_resolution CHECK (
        statut <> 'resolu' OR (decision IS NOT NULL AND id_admin IS NOT NULL AND date_resolution IS NOT NULL)),
    CONSTRAINT ck_litige_remboursement CHECK (
        decision IS DISTINCT FROM 'remboursement_partiel' OR coalesce(montant_rembourse, 0) > 0)  -- NULL refusé
);

CREATE TABLE avis (                                                            -- Noter
    id_avis      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_livraison UUID NOT NULL REFERENCES livraison(id_livraison) ON DELETE CASCADE,
    type_auteur  type_auteur_avis NOT NULL,
    note         SMALLINT NOT NULL CHECK (note BETWEEN 1 AND 5),
    commentaire  VARCHAR(500),
    date_avis    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (id_livraison, type_auteur)                                         -- 2 avis max par livraison
);

-- Journal d'audit des actions sensibles (exigence sécurité §5.2)
CREATE TABLE audit_log (
    id_audit       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_utilisateur UUID REFERENCES utilisateur(id_utilisateur),
    action         VARCHAR(60) NOT NULL,
    table_cible    VARCHAR(60),
    id_cible       TEXT,
    details        JSONB,
    adresse_ip     INET,
    date_action    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 7. Index
-- ---------------------------------------------------------------------
CREATE INDEX ix_utilisateur_role            ON utilisateur(role);
CREATE INDEX ix_utilisateur_transporteur    ON utilisateur(id_transporteur);
CREATE INDEX ix_kyc_utilisateur             ON document_kyc(id_utilisateur);
CREATE INDEX ix_kyc_a_verifier              ON document_kyc(date_depot) WHERE statut_verification = 'en_attente';
CREATE INDEX ix_notification_non_lue        ON notification(id_utilisateur, date_envoi DESC) WHERE NOT est_lue;
CREATE INDEX ix_zone_ville                  ON zone_intervention(id_ville);
CREATE INDEX ix_demande_marchand            ON demande(id_marchand, created_at DESC);
CREATE INDEX ix_demande_statut_depart       ON demande(statut, id_ville_depart);   -- missions disponibles par zone
CREATE INDEX ix_demande_created             ON demande(created_at);
CREATE INDEX ix_historique_demande          ON historique_statut(id_demande, date_changement);
CREATE INDEX ix_evaluation_demande          ON evaluation(id_demande);
CREATE INDEX ix_evaluation_representant     ON evaluation(id_representant, date_acceptation DESC);
CREATE INDEX ix_message_devis               ON message_negociation(id_devis, date_envoi);
CREATE INDEX ix_paiement_devis              ON paiement(id_devis);
CREATE INDEX ix_livraison_chauffeur         ON livraison(id_chauffeur);
CREATE INDEX ix_position_livraison          ON position_gps(id_livraison, horodatage DESC);
CREATE INDEX ix_incident_livraison          ON incident(id_livraison);
CREATE INDEX ix_photo_demande               ON photo(id_demande)    WHERE id_demande    IS NOT NULL;
CREATE INDEX ix_photo_evaluation            ON photo(id_evaluation) WHERE id_evaluation IS NOT NULL;
CREATE INDEX ix_photo_livraison             ON photo(id_livraison)  WHERE id_livraison  IS NOT NULL;
CREATE INDEX ix_litige_statut               ON litige(statut);
CREATE INDEX ix_audit_utilisateur           ON audit_log(id_utilisateur, date_action DESC);

-- ---------------------------------------------------------------------
-- 8. Fonctions et triggers (règles de gestion)
-- ---------------------------------------------------------------------

-- updated_at automatique
CREATE FUNCTION trg_set_updated_at() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END $$;

CREATE TRIGGER tg_transporteur_updated BEFORE UPDATE ON transporteur FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
CREATE TRIGGER tg_utilisateur_updated  BEFORE UPDATE ON utilisateur  FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
CREATE TRIGGER tg_demande_updated      BEFORE UPDATE ON demande      FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
CREATE TRIGGER tg_livraison_updated    BEFORE UPDATE ON livraison    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

-- Vérification du rôle d'un utilisateur référencé
CREATE FUNCTION assert_role(p_user UUID, p_roles role_utilisateur[], p_contexte TEXT)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_role role_utilisateur;
BEGIN
    IF p_user IS NULL THEN RETURN; END IF;
    SELECT role INTO v_role FROM utilisateur WHERE id_utilisateur = p_user;
    IF v_role IS NULL OR NOT v_role = ANY (p_roles) THEN
        RAISE EXCEPTION '% : l''utilisateur % doit avoir le rôle %, rôle actuel : %',
            p_contexte, p_user, p_roles, coalesce(v_role::text, 'inconnu')
            USING ERRCODE = 'check_violation';
    END IF;
END $$;

CREATE FUNCTION trg_check_roles() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    CASE TG_TABLE_NAME
        WHEN 'demande'           THEN PERFORM assert_role(NEW.id_marchand,     ARRAY['marchand']::role_utilisateur[],     'Créer une demande');
        WHEN 'evaluation'        THEN PERFORM assert_role(NEW.id_representant, ARRAY['representant']::role_utilisateur[], 'Effectuer une évaluation');
        WHEN 'zone_intervention' THEN PERFORM assert_role(NEW.id_utilisateur,  ARRAY['representant']::role_utilisateur[], 'Couvrir une zone');
        WHEN 'livraison'         THEN PERFORM assert_role(NEW.id_chauffeur,    ARRAY['chauffeur']::role_utilisateur[],    'Exécuter une livraison');
        WHEN 'litige'            THEN PERFORM assert_role(NEW.id_admin,        ARRAY['admin']::role_utilisateur[],        'Arbitrer un litige');
    END CASE;
    RETURN NEW;
END $$;

CREATE TRIGGER tg_demande_role    BEFORE INSERT OR UPDATE OF id_marchand     ON demande           FOR EACH ROW EXECUTE FUNCTION trg_check_roles();
CREATE TRIGGER tg_evaluation_role BEFORE INSERT OR UPDATE OF id_representant ON evaluation        FOR EACH ROW EXECUTE FUNCTION trg_check_roles();
CREATE TRIGGER tg_zone_role       BEFORE INSERT OR UPDATE                    ON zone_intervention FOR EACH ROW EXECUTE FUNCTION trg_check_roles();
CREATE TRIGGER tg_livraison_role  BEFORE INSERT OR UPDATE OF id_chauffeur    ON livraison         FOR EACH ROW EXECUTE FUNCTION trg_check_roles();
CREATE TRIGGER tg_litige_role     BEFORE INSERT OR UPDATE OF id_admin        ON litige            FOR EACH ROW EXECUTE FUNCTION trg_check_roles();

-- Numéro de demande TC-AAAA-NNNNN
CREATE FUNCTION trg_demande_numero() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.numero IS NULL THEN
        NEW.numero := 'TC-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('demande_numero_seq')::text, 5, '0');
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_demande_numero BEFORE INSERT ON demande FOR EACH ROW EXECUTE FUNCTION trg_demande_numero();

-- Historisation des statuts (timeline de suivi)
CREATE FUNCTION trg_historiser_statut() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO historique_statut(id_demande, ancien_statut, nouveau_statut) VALUES (NEW.id_demande, NULL, NEW.statut);
    ELSIF NEW.statut IS DISTINCT FROM OLD.statut THEN
        INSERT INTO historique_statut(id_demande, ancien_statut, nouveau_statut) VALUES (NEW.id_demande, OLD.statut, NEW.statut);
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_demande_historique AFTER INSERT OR UPDATE OF statut ON demande
    FOR EACH ROW EXECUTE FUNCTION trg_historiser_statut();

-- Négociation : 3 allers-retours maximum (3 messages par émetteur)
CREATE FUNCTION trg_limite_negociation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT count(*) FROM message_negociation
        WHERE id_devis = NEW.id_devis AND emetteur = NEW.emetteur) >= 3 THEN
        RAISE EXCEPTION 'Négociation limitée à 3 allers-retours pour le devis %', NEW.id_devis
            USING ERRCODE = 'check_violation';
    END IF;
    IF (SELECT statut FROM devis WHERE id_devis = NEW.id_devis) NOT IN ('propose', 'en_negociation') THEN
        RAISE EXCEPTION 'Le devis % n''est plus négociable', NEW.id_devis USING ERRCODE = 'check_violation';
    END IF;
    UPDATE devis SET statut = 'en_negociation' WHERE id_devis = NEW.id_devis AND statut = 'propose';
    RETURN NEW;
END $$;
CREATE TRIGGER tg_message_limite BEFORE INSERT ON message_negociation
    FOR EACH ROW EXECUTE FUNCTION trg_limite_negociation();

-- Évaluation : au moins 2 photos avant soumission
CREATE FUNCTION trg_evaluation_photos() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.date_soumission IS NOT NULL AND OLD.date_soumission IS NULL AND
       (SELECT count(*) FROM photo WHERE id_evaluation = NEW.id_evaluation) < 2 THEN
        RAISE EXCEPTION 'Une évaluation doit comporter au moins 2 photos avant soumission'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_evaluation_photos BEFORE UPDATE OF date_soumission ON evaluation
    FOR EACH ROW EXECUTE FUNCTION trg_evaluation_photos();

-- Paiement réussi : séquestre bloqué, devis accepté, demande PAYE
CREATE FUNCTION trg_paiement_reussi() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_demande UUID;
BEGIN
    IF NEW.statut = 'reussi' AND (TG_OP = 'INSERT' OR OLD.statut IS DISTINCT FROM 'reussi') THEN
        NEW.statut_sequestre := coalesce(NEW.statut_sequestre, 'bloque');
        NEW.date_paiement    := coalesce(NEW.date_paiement, now());
        UPDATE devis SET statut = 'accepte' WHERE id_devis = NEW.id_devis;
        SELECT e.id_demande INTO v_demande
          FROM devis d JOIN evaluation e ON e.id_evaluation = d.id_evaluation
         WHERE d.id_devis = NEW.id_devis;
        UPDATE demande SET statut = 'PAYE' WHERE id_demande = v_demande;
    END IF;
    IF NEW.statut_sequestre = 'libere' AND NEW.date_liberation IS NULL THEN
        NEW.date_liberation := now();
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_paiement_reussi BEFORE INSERT OR UPDATE OF statut, statut_sequestre ON paiement
    FOR EACH ROW EXECUTE FUNCTION trg_paiement_reussi();

-- Livraison : synchronise le statut de la demande
CREATE FUNCTION trg_livraison_statut() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.statut IN ('enleve', 'en_transit', 'arrive') THEN
        UPDATE demande SET statut = 'EN_TRANSIT' WHERE id_demande = NEW.id_demande AND statut <> 'EN_TRANSIT';
    ELSIF NEW.statut = 'livre' THEN
        UPDATE demande SET statut = 'LIVRE' WHERE id_demande = NEW.id_demande;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_livraison_statut AFTER UPDATE OF statut ON livraison
    FOR EACH ROW WHEN (NEW.statut IS DISTINCT FROM OLD.statut) EXECUTE FUNCTION trg_livraison_statut();

-- Litige ouvert : demande passe en LITIGE
CREATE FUNCTION trg_litige_ouvert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE demande SET statut = 'LITIGE' WHERE id_demande = NEW.id_demande;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_litige_ouvert AFTER INSERT ON litige FOR EACH ROW EXECUTE FUNCTION trg_litige_ouvert();

-- Avis : recalcul des notes moyennes (marchand noté par le transporteur, et inversement)
CREATE FUNCTION trg_avis_note() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_marchand UUID; v_transporteur UUID;
BEGIN
    SELECT d.id_marchand, r.id_transporteur INTO v_marchand, v_transporteur
      FROM livraison l
      JOIN demande d    ON d.id_demande = l.id_demande
      JOIN evaluation e ON e.id_demande = d.id_demande
      JOIN devis dv     ON dv.id_evaluation = e.id_evaluation AND dv.statut = 'accepte'
      JOIN utilisateur r ON r.id_utilisateur = e.id_representant
     WHERE l.id_livraison = NEW.id_livraison;

    IF NEW.type_auteur = 'marchand' THEN
        UPDATE transporteur t SET (note_moyenne, nb_avis) = (
            SELECT round(avg(a.note), 1), count(*)
              FROM avis a JOIN livraison l ON l.id_livraison = a.id_livraison
              JOIN evaluation e ON e.id_demande = l.id_demande
              JOIN devis dv ON dv.id_evaluation = e.id_evaluation AND dv.statut = 'accepte'
              JOIN utilisateur r ON r.id_utilisateur = e.id_representant
             WHERE a.type_auteur = 'marchand' AND r.id_transporteur = v_transporteur)
         WHERE t.id_transporteur = v_transporteur;
    ELSE
        UPDATE utilisateur u SET (note_moyenne, nb_avis) = (
            SELECT round(avg(a.note), 1), count(*)
              FROM avis a JOIN livraison l ON l.id_livraison = a.id_livraison
              JOIN demande d ON d.id_demande = l.id_demande
             WHERE a.type_auteur = 'transporteur' AND d.id_marchand = v_marchand)
         WHERE u.id_utilisateur = v_marchand;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_avis_note AFTER INSERT ON avis FOR EACH ROW EXECUTE FUNCTION trg_avis_note();

-- Calcul du prix suggéré : base + distance × tarif_km + poids × tarif_kg, × coef type, + express
CREATE FUNCTION calculer_prix_suggere(p_grille UUID, p_distance_km NUMERIC, p_poids_kg NUMERIC,
                                      p_type type_marchandise, p_urgence niveau_urgence)
RETURNS INTEGER LANGUAGE sql STABLE AS $$
    SELECT (round(
              (g.prix_base + p_distance_km * g.tarif_km + p_poids_kg * g.tarif_kg)
              * coalesce((g.coef_type_marchandise ->> p_type::text)::numeric, 1)
              + CASE WHEN p_urgence = 'express' THEN g.supplement_express ELSE 0 END
            , -2))::INTEGER                                                    -- arrondi à la centaine
      FROM grille_tarifaire g WHERE g.id_grille = p_grille;
$$;

-- ---------------------------------------------------------------------
-- 9. Vues
-- ---------------------------------------------------------------------

-- Suivi d'une demande côté marchand (dernier devis, paiement, livraison)
CREATE VIEW v_suivi_demande AS
SELECT d.id_demande, d.numero, d.statut,
       vd.nom_ville AS ville_depart, va.nom_ville AS ville_arrivee,
       d.type_marchandise, d.poids_estime, d.urgence, d.date_enlevement,
       m.nom_complet AS marchand,
       rep.nom_complet AS representant, t.raison_sociale AS transporteur,
       dv.prix_propose, dv.delai_jours, dv.statut AS statut_devis,
       p.statut AS statut_paiement, p.statut_sequestre,
       l.statut AS statut_livraison, l.date_arrivee_estimee,
       d.created_at
  FROM demande d
  JOIN ville vd ON vd.id_ville = d.id_ville_depart
  JOIN ville va ON va.id_ville = d.id_ville_arrivee
  JOIN utilisateur m ON m.id_utilisateur = d.id_marchand
  LEFT JOIN LATERAL (SELECT * FROM evaluation e WHERE e.id_demande = d.id_demande
                     ORDER BY e.date_acceptation DESC LIMIT 1) ev ON TRUE
  LEFT JOIN utilisateur rep ON rep.id_utilisateur = ev.id_representant
  LEFT JOIN transporteur t  ON t.id_transporteur = rep.id_transporteur
  LEFT JOIN devis dv        ON dv.id_evaluation = ev.id_evaluation
  LEFT JOIN LATERAL (SELECT * FROM paiement pa WHERE pa.id_devis = dv.id_devis
                     ORDER BY (pa.statut = 'reussi') DESC, pa.created_at DESC LIMIT 1) p ON TRUE
  LEFT JOIN livraison l ON l.id_demande = d.id_demande;

-- Missions disponibles pour un représentant (filtrer par id_representant)
CREATE VIEW v_missions_disponibles AS
SELECT z.id_utilisateur AS id_representant, d.id_demande, d.numero,
       vd.nom_ville AS ville_depart, va.nom_ville AS ville_arrivee,
       d.adresse_depart, m.nom_complet AS marchand, m.note_moyenne AS note_marchand,
       d.type_marchandise, d.description, d.poids_estime, d.volume_estime,
       d.urgence, d.date_enlevement, d.created_at
  FROM demande d
  JOIN zone_intervention z ON z.id_ville = d.id_ville_depart
  JOIN ville vd ON vd.id_ville = d.id_ville_depart
  JOIN ville va ON va.id_ville = d.id_ville_arrivee
  JOIN utilisateur m ON m.id_utilisateur = d.id_marchand
 WHERE d.statut = 'EN_ATTENTE';

-- Indicateurs du tableau de bord admin (30 derniers jours)
CREATE VIEW v_kpi_admin AS
SELECT
  (SELECT count(*) FROM demande WHERE created_at >= now() - INTERVAL '30 days')            AS demandes_30j,
  (SELECT count(*) FROM transporteur WHERE statut = 'actif')                                AS transporteurs_actifs,
  (SELECT count(*) FROM utilisateur WHERE role = 'marchand')                                AS marchands_inscrits,
  (SELECT coalesce(sum(montant), 0) FROM paiement
    WHERE statut = 'reussi' AND date_paiement >= now() - INTERVAL '30 days')               AS chiffre_affaires_30j,
  (SELECT coalesce(sum(montant_commission), 0) FROM paiement
    WHERE statut = 'reussi' AND date_paiement >= now() - INTERVAL '30 days')               AS commissions_30j,
  (SELECT round(100.0 * count(*) FILTER (WHERE statut = 'accepte') / nullif(count(*), 0), 1)
     FROM devis WHERE date_emission >= now() - INTERVAL '30 days')                         AS taux_conversion_pct,
  (SELECT round(100.0 * (SELECT count(*) FROM litige) / nullif(count(*), 0), 2)
     FROM livraison)                                                                        AS taux_litige_pct,
  (SELECT count(*) FROM litige WHERE statut <> 'resolu')                                    AS litiges_ouverts;

-- Zones les plus actives
CREATE VIEW v_zones_actives AS
SELECT v.nom_ville, count(d.id_demande) AS nb_demandes
  FROM ville v LEFT JOIN demande d ON d.id_ville_depart = v.id_ville
 GROUP BY v.nom_ville ORDER BY nb_demandes DESC;

-- ---------------------------------------------------------------------
-- 10. search_path des fonctions
-- ---------------------------------------------------------------------
-- Les triggers référencent les tables sans préfixe de schéma : on fixe leur search_path
-- pour qu'ils fonctionnent quel que soit celui du client (API, outils d'administration…).
DO $$
DECLARE f regprocedure;
BEGIN
    FOR f IN SELECT p.oid::regprocedure FROM pg_proc p WHERE p.pronamespace = 'transconnect'::regnamespace LOOP
        EXECUTE format('ALTER FUNCTION %s SET search_path = transconnect, public', f);
    END LOOP;
END $$;

COMMIT;

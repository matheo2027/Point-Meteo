-- Point-Meteo initial schema for Neon / PostgreSQL
-- Idempotent migration: safe to run on an empty database.

BEGIN;

CREATE TABLE IF NOT EXISTS villes (
    id BIGSERIAL PRIMARY KEY,
    nom TEXT NOT NULL UNIQUE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL
);

CREATE TABLE IF NOT EXISTS donnees_meteo (
    id BIGSERIAL PRIMARY KEY,
    ville_id BIGINT NOT NULL REFERENCES villes(id) ON DELETE CASCADE,
    source TEXT NOT NULL,
    temp DOUBLE PRECISION NOT NULL,
    code_meteo INTEGER NOT NULL DEFAULT 0,
    date_concernee DATE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('prevision', 'realite')),
    date_enregistrement TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_donnees_meteo_unique UNIQUE (ville_id, source, date_concernee, type)
);

CREATE TABLE IF NOT EXISTS scores_fiabilite (
    id BIGSERIAL PRIMARY KEY,
    ville_id BIGINT NOT NULL REFERENCES villes(id) ON DELETE CASCADE,
    source TEXT NOT NULL,
    score_fiabilite NUMERIC(5, 2) NOT NULL DEFAULT 0,
    derniere_maj TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_scores_fiabilite_unique UNIQUE (ville_id, source),
    CONSTRAINT ck_scores_fiabilite_range CHECK (score_fiabilite >= 0 AND score_fiabilite <= 100)
);

CREATE INDEX IF NOT EXISTS idx_donnees_meteo_ville_date
    ON donnees_meteo (ville_id, date_concernee);

CREATE INDEX IF NOT EXISTS idx_donnees_meteo_ville_source_type_date
    ON donnees_meteo (ville_id, source, type, date_concernee);

CREATE INDEX IF NOT EXISTS idx_donnees_meteo_source_type_date
    ON donnees_meteo (source, type, date_concernee);

CREATE INDEX IF NOT EXISTS idx_donnees_meteo_source_type_date_enregistrement
    ON donnees_meteo (source, type, date_enregistrement DESC);

CREATE INDEX IF NOT EXISTS idx_scores_fiabilite_ville_source
    ON scores_fiabilite (ville_id, source);

CREATE INDEX IF NOT EXISTS idx_scores_fiabilite_source
    ON scores_fiabilite (source);

CREATE OR REPLACE FUNCTION set_donnees_meteo_date_enregistrement()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.date_enregistrement = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_donnees_meteo_date_enregistrement ON donnees_meteo;

CREATE TRIGGER trg_set_donnees_meteo_date_enregistrement
BEFORE UPDATE ON donnees_meteo
FOR EACH ROW
EXECUTE FUNCTION set_donnees_meteo_date_enregistrement();

COMMIT;
import pandas as pd
from sqlalchemy import create_engine, text
import os
from pathlib import Path


def _load_env_if_exists(env_path):
    if not env_path.exists():
        return
    for raw_line in env_path.read_text(encoding='utf-8').splitlines():
        line = raw_line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


_SCRIPT_DIR = Path(__file__).resolve().parent
_BACKEND_DIR = _SCRIPT_DIR.parent
_load_env_if_exists(_BACKEND_DIR / '.env')
_load_env_if_exists(_SCRIPT_DIR / '.env')

REFERENCE_SOURCE = os.getenv('REFERENCE_SOURCE', 'Reference-Obs')

# Score sur 100 conservé, mais plus progressif qu'un simple "-10 par degré"
SCORE_PER_DEGREE = float(os.getenv('SCORE_PER_DEGREE', '6.0'))
FULL_CONFIDENCE_DAYS = int(os.getenv('FULL_CONFIDENCE_DAYS', '7'))
MIN_REQUIRED_MATCHES = int(os.getenv('MIN_REQUIRED_MATCHES', '3'))


def _db_url():
    database_url = os.getenv('DATABASE_URL')
    if database_url:
        if 'sslmode=' not in database_url:
            separator = '&' if '?' in database_url else '?'
            database_url = f'{database_url}{separator}sslmode=require'
        return database_url

    user = os.getenv('DB_USER', 'postgres')
    password = os.getenv('DB_PASSWORD', '')
    host = os.getenv('DB_HOST', 'localhost')
    port = os.getenv('DB_PORT', '5432')
    db_name = os.getenv('DB_NAME', 'meteo_db')
    return f'postgresql://{user}:{password}@{host}:{port}/{db_name}'


engine = create_engine(_db_url())

def calculer_fiabilite():
    print("Demarrage de l'analyse haute performance...")
    
    # 2. On charge tout en mémoire avec une seule requête SQL
    query = """
    SELECT ville_id, source, temp, date_concernee, type 
    FROM donnees_meteo 
    WHERE date_concernee >= CURRENT_DATE - INTERVAL '7 days'
    """
    df = pd.read_sql(query, engine)

    if df.empty:
        print("INFO: Pas assez de donnees pour l'analyse.")
        return

    # 3. On sépare Prévisions et Réalité (référence indépendante)
    previsions = df[df['type'] == 'prevision']
    realite = df[(df['type'] == 'realite') & (df['source'] == REFERENCE_SOURCE)]

    if realite.empty:
        print(f"INFO: Aucune donnee de reference trouvee (source='{REFERENCE_SOURCE}').")
        return

    # 4. Fusion prévisions vs vérité terrain, par ville et date
    comparaison = pd.merge(
        previsions, 
        realite[['ville_id', 'date_concernee', 'temp']], 
        on=['ville_id', 'date_concernee'], 
        suffixes=('_prev', '_reel')
    )

    if comparaison.empty:
        print("INFO: Pas de chevauchement prevision/realite de reference sur la fenetre de 7 jours.")
        return

    # 5. Calcul de l'erreur absolue : |Temp_Prévue - Temp_Réelle|
    comparaison['erreur'] = (comparaison['temp_prev'] - comparaison['temp_reel']).abs()

    # 6. Agrégation MAE + taille d'échantillon par ville/source
    scores = (
        comparaison
        .groupby(['ville_id', 'source'])
        .agg(
            erreur=('erreur', 'mean'),
            nb_points=('erreur', 'count')
        )
        .reset_index()
    )

    # Filtre anti-bruit: évite de classer sur 1 ou 2 jours seulement
    scores = scores[scores['nb_points'] >= MIN_REQUIRED_MATCHES].copy()
    if scores.empty:
        print("INFO: Donnees insuffisantes apres filtre de fiabilite minimale.")
        return

    # Score sur 100 conservé, avec pénalité progressive + facteur confiance lié au volume
    scores['base_score'] = (100 - (scores['erreur'] * SCORE_PER_DEGREE)).clip(lower=0, upper=100)
    scores['confidence'] = (scores['nb_points'] / FULL_CONFIDENCE_DAYS).clip(lower=0.3, upper=1.0)
    scores['score'] = (scores['base_score'] * (0.7 + 0.3 * scores['confidence'])).round(2)

    # 7. Mise à jour massive de la base de données (Version SQLAlchemy 2.0+)
    with engine.begin() as conn:  # Utilise un contexte de connexion
        for _, row in scores.iterrows():
            update_query = text("""
                INSERT INTO scores_fiabilite (ville_id, source, score_fiabilite, derniere_maj)
                VALUES (:ville_id, :source, :score, NOW())
                ON CONFLICT (ville_id, source) 
                DO UPDATE SET score_fiabilite = EXCLUDED.score_fiabilite, derniere_maj = NOW()
            """)
            
            conn.execute(update_query, {
                "ville_id": int(row['ville_id']),
                "source": row['source'],
                "score": float(row['score'])
            })

    print(f"Analyse terminée pour {len(scores)} combinaisons Ville/Source.")

if __name__ == "__main__":
    calculer_fiabilite()
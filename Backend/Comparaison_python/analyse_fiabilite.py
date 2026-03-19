import pandas as pd
from sqlalchemy import create_engine, text
import datetime

# 1. Connexion ultra-rapide via SQLAlchemy
engine = create_engine('postgresql://postgres:RrDlTbKrpNPg1yDY@localhost:5432/meteo_db')

def calculer_fiabilite():
    print("Démarrage de l'analyse haute performance...")
    
    # 2. On charge tout en mémoire avec une seule requête SQL
    query = """
    SELECT ville_id, source, temp, date_concernee, type 
    FROM donnees_meteo 
    WHERE date_concernee >= CURRENT_DATE - INTERVAL '7 days'
    """
    df = pd.read_sql(query, engine)

    if df.empty:
        print("ℹPas assez de données pour l'analyse.")
        return

    # 3. On sépare Prévisions et Réalité
    previsions = df[df['type'] == 'prevision']
    realite = df[df['type'] == 'realite']

    # 4. LE CŒUR DE L'ALGO : On fusionne les deux sur la date et la ville
    # Cela permet de comparer directement la prévision d'une source avec la réalité
    comparaison = pd.merge(
        previsions, 
        realite[['ville_id', 'date_concernee', 'temp']], 
        on=['ville_id', 'date_concernee'], 
        suffixes=('_prev', '_reel')
    )

    # 5. Calcul de l'erreur absolue : |Temp_Prévue - Temp_Réelle|
    comparaison['erreur'] = (comparaison['temp_prev'] - comparaison['temp_reel']).abs()

    # 6. Groupement par ville et source pour avoir le score moyen
    # Plus l'erreur est proche de 0, plus la source est fiable
    scores = comparaison.groupby(['ville_id', 'source'])['erreur'].mean().reset_index()

    # Transformation de l'erreur en score sur 100 (ex: 0° d'erreur = 100%, 5° d'erreur = 50%)
    scores['score'] = scores['erreur'].apply(lambda x: max(0, 100 - (x * 10)))

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
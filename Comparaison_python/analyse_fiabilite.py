import psycopg2
import pandas as pd
import os
from dotenv import load_dotenv

load_dotenv()

def calculer_erreurs():
    try:
        conn = psycopg2.connect(
            host=os.getenv("DB_HOST"),
            database=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD")
        )

        query = """
        SELECT 
            p.ville_id,
            p.source,
            p.temp as temp_prevue,
            o.temp as temp_reelle,
            ABS(p.temp - o.temp) as ecart
        FROM donnees_meteo p
        JOIN donnees_meteo o ON p.ville_id = o.ville_id 
             AND p.date_concernee = o.date_concernee
        WHERE p.type = 'prevision' 
          AND o.type = 'observation'
          AND p.date_concernee = CURRENT_DATE - INTERVAL '1 day';
        """
        
        df = pd.read_sql_query(query, conn)
        
        if df.empty:
            print("Aucune donnée à comparer pour hier.")
        else:
            # Calcul de la moyenne par ville et par source
            bilan = df.groupby(['ville_id', 'source'])['ecart'].mean().reset_index()
            
            # Sauvegarde SQL de tous les scores
            cur = conn.cursor()
            for index, row in bilan.iterrows():
                score_final = max(0, 100 - (float(row['ecart']) * 10))
                query_upsert = """
                INSERT INTO scores_fiabilite (ville_id, source, score_fiabilite, derniere_maj)
                VALUES (%s, %s, %s, CURRENT_TIMESTAMP)
                ON CONFLICT (ville_id, source) 
                DO UPDATE SET score_fiabilite = EXCLUDED.score_fiabilite, derniere_maj = CURRENT_TIMESTAMP;
                """
                cur.execute(query_upsert, (int(row['ville_id']), row['source'], score_final))
            
            conn.commit()
            cur.close()

            # --- IDENTIFICATION DU GAGNANT PAR VILLE ---
            # On trie par ville et par ecart croissant, puis on prend le premier de chaque groupe
            gagnants = bilan.sort_values('ecart').groupby('ville_id').first().reset_index()

            print("Synthèse de la fiabilité (Hier) :")
            print(bilan)
            print("\nSource la plus fiable par ville :")
            print(gagnants[['ville_id', 'source', 'ecart']])
            print("\nScores mis à jour dans la table 'scores_fiabilite'.")

        conn.close()
    except Exception as e:
        print(f"Erreur : {e}")

if __name__ == "__main__":
    calculer_erreurs()
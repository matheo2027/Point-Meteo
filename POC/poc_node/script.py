import pandas as pd
import json

#Charge le fichier JSON dans un DataFrame
df = pd.read_json('data.json')

#Calcule de l'écart pour chaque ligne
#"abs" = valeur absolue
df['ecart_A'] = abs(df['source_A'] - df['reelle'])

#Moyenne de la nouvelle colonne
score_moyen = df['ecart_A'].mean()

#Prépare l'affichage du résultat
resultat = {"score_moyen_A": score_moyen}

#Résultat final en format JSON
print(json.dumps(resultat))
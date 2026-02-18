#!/bin/bash

echo "🚀 Démarrage de l'écosystème Point-Météo..."

# 1. Nettoyage et installation des dépendances Backend
echo "📦 Installation des dépendances Backend..."
cd Backend
npm install

# 2. Installation des dépendances Python (si nécessaire)
echo "🐍 Vérification des dépendances Python..."
pip install pandas sqlalchemy psycopg2-binary cryptography  --quiet

# 3. Lancement du Backend dans un nouveau terminal
echo "🌐 Lancement du serveur Node.js..."
# Sur Windows (avec Git Bash), on utilise 'start' pour ouvrir une nouvelle fenêtre
start "BACKEND - Node.js" bash -c "node server.js; exec bash"

# 4. Lancement de l'analyse Python initiale
cd ..
echo "📊 Calcul des scores de fiabilité..."
python Comparaison_python/analyse_fiabilite.py

# 5. Lancement du Frontend Flutter
echo "📱 Lancement de l'application Flutter..."
cd point_meteo_app
# On lance flutter run (assure-toi qu'un émulateur est allumé)
start "FRONTEND - Flutter" bash -c "flutter run; exec bash"

echo "✅ Tout est lancé ! Regarde les fenêtres séparées pour les logs."
#!/bin/bash

echo "🚀 Démarrage de l'écosystème Point-Météo..."

# 1. Lancement du Frontend Flutter
echo "📱 Lancement de l'application Flutter..."
cd point_meteo_app
start "FRONTEND - Flutter" bash -c "flutter run; exec bash"

echo "✅ Tout est lancé ! Regarde les fenêtres séparées pour les logs."
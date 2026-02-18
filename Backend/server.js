const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

console.log("🔍 Tentative de lecture du .env à :", path.join(__dirname, '.env'));
// Petit test de debug
console.log("Clé Meteo-Concept présente :", !!process.env.METEOCONCEPT_API_KEY);

const express = require('express');
const axios = require('axios');
const cron = require('node-cron');
const { getOrCreateVille, pool } = require('./db');
const { fetchAndStoreAllForecasts, fetchAndStoreAllRealData } = require('./weatherService');
const { exec } = require('child_process');

const app = express();
app.use(express.json());

// ROUTE 1 : Recherche
app.get('/search/:nom', async (req, res) => {
    const nomVille = req.params.nom;

    try {
        // 1. Vérifier si la ville existe déjà dans la base de données
        const result = await pool.query(
            "SELECT id, nom, latitude, longitude FROM villes WHERE LOWER(nom) = LOWER($1)", 
            [nomVille]
        );

        if (result.rows.length > 0) {
            const villeExistante = result.rows[0];
            console.log(`✅ Ville trouvée en base : ${villeExistante.nom}`);
            
            // On renvoie directement la ville sans appeler les API de géocodage
            return res.json({ 
                id: villeExistante.id, 
                ville: villeExistante.nom, 
                coords: { 
                    latitude: villeExistante.latitude, 
                    longitude: villeExistante.longitude 
                } 
            });
        }

        // 2. Si la ville n'existe pas, on fetch depuis l'API de géocodage
        console.log(`🔍 Ville non trouvée en base. Recherche via API pour : ${nomVille}`);
        const geoUrl = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(nomVille)}&count=1&language=fr&format=json`;
        const geoRes = await axios.get(geoUrl);

        if (!geoRes.data.results) {
            return res.status(404).json({ error: "Ville non trouvée" });
        }

        const { latitude, longitude, name } = geoRes.data.results[0];
        
        // 3. Créer la ville et collecter les données météo initiales
        const villeId = await getOrCreateVille(name, latitude, longitude);

        // On lance la collecte uniquement pour les nouvelles villes
        await fetchAndStoreAllForecasts(villeId, latitude, longitude);
        await fetchAndStoreAllRealData(villeId, latitude, longitude);

        res.json({ id: villeId, ville: name, coords: { latitude, longitude } });

    } catch (err) {
        console.error("❌ Erreur route search :", err.message);
        res.status(500).json({ error: err.message });
    }
});

// ROUTE 2 : Récupérer la météo stockée
app.get('/weather/:villeId', async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT * FROM donnees_meteo 
             WHERE ville_id = $1 
             AND date_concernee::date >= CURRENT_DATE 
             ORDER BY date_concernee ASC, id DESC`, // id DESC pour prendre la ligne la plus récente si doublons
            [req.params.villeId]
        );
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ROUTE 3 : Récupérer les scores de fiabilité
app.get('/scores/:villeId', async (req, res) => {
    try {
        const result = await pool.query(
            "SELECT * FROM scores_fiabilite WHERE ville_id = $1",
            [req.params.villeId]
        );
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ROUTE 4 : Récupérer les coordonnées gps
app.get('/search-coords', async (req, res) => {
    const { lat, lon } = req.query;
    console.log(`📍 Reverse Geocoding pour : Lat ${lat}, Lon ${lon}`);

    try {
        // Nouvelle API : Plus rapide et pas de restriction d'User-Agent
        const geoUrl = `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=fr`;
        
        const response = await axios.get(geoUrl);
        
        // On récupère le nom de la ville (city) ou de la localité (locality)
        const cityName = response.data.city || response.data.locality || "Ville inconnue";

        console.log(`🏙️ Ville détectée : ${cityName}`);

        // Utilisation de ta fonction dans db.js
        const villeId = await getOrCreateVille(cityName, lat, lon);

        res.json({ 
            id: villeId, 
            ville: cityName 
        });

    } catch (err) {
        console.error("❌ Erreur API Geocoding :", err.message);
        res.status(500).json({ error: "Impossible de localiser la ville" });
    }
});

// CRONS OPTIMISÉS
cron.schedule('0 */3 * * *', async () => {
    console.log("🕒 [Cron] Prévisions...");
    const villes = await pool.query("SELECT * FROM villes");
    for (const v of villes.rows) {
        await fetchAndStoreAllForecasts(v.id, v.latitude, v.longitude);
    }
});

cron.schedule('14 0 * * *', async () => {
    console.log("🕒 [Cron] Réalité veille...");
    const villes = await pool.query("SELECT * FROM villes");
    for (const v of villes.rows) {
        await fetchAndStoreAllRealData(v.id, v.latitude, v.longitude);
    }
    exec('python ./Comparaison_python/analyse_fiabilite.py', (error, stdout, stderr) => {
        if (error) {
            console.error(`❌ Erreur Analyse Python: ${error.message}`);
            return;
        }
        console.log(`📊 Analyse de fiabilité terminée : ${stdout}`);
    });
});

app.listen(3000,'0.0.0.0', () => console.log("Serveur multi-sources prêt sur port 3000"));
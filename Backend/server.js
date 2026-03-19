const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

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
        const result = await pool.query(
            "SELECT id, nom, latitude, longitude FROM villes WHERE LOWER(nom) = LOWER($1)", 
            [nomVille]
        );

        if (result.rows.length > 0) {
            const villeExistante = result.rows[0];
            console.log(`✅ Ville trouvée en base : ${villeExistante.nom}`);
            
            // Vérifier si on a des données fraîches pour AUJOURD'HUI
            const checkData = await pool.query(
                "SELECT id FROM donnees_meteo WHERE ville_id = $1 AND date_concernee::date = CURRENT_DATE LIMIT 1",
                [villeExistante.id]
            );

            if (checkData.rows.length === 0) {
                console.log(`⚠️ Données obsolètes pour ${villeExistante.nom}. Lancement d'un fetch d'urgence !`);
                await fetchAndStoreAllForecasts(villeExistante.id, villeExistante.latitude, villeExistante.longitude);
            } else {
                console.log(`✅ Données météo à jour pour ${villeExistante.nom}.`);
            }

            return res.json({ 
                id: villeExistante.id, 
                ville: villeExistante.nom, 
                coords: { latitude: villeExistante.latitude, longitude: villeExistante.longitude } 
            });
        }

        console.log(`🔍 Ville non trouvée en base. Recherche via API pour : ${nomVille}`);
        const geoUrl = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(nomVille)}&count=1&language=fr&format=json`;
        const geoRes = await axios.get(geoUrl);

        if (!geoRes.data.results) {
            return res.status(404).json({ error: "Ville non trouvée" });
        }

        const { latitude, longitude, name } = geoRes.data.results[0];
        const villeId = await getOrCreateVille(name, latitude, longitude);

        console.log(`📥 Lancement du premier fetch pour ${name}...`);
        await fetchAndStoreAllForecasts(villeId, latitude, longitude);
        await fetchAndStoreAllRealData(villeId, latitude, longitude);

        res.json({ id: villeId, ville: name, coords: { latitude, longitude } });

    } catch (err) {
        console.error("❌ Erreur route search :", err.message);
        res.status(500).json({ error: err.message });
    }
});

// ROUTE 2 : Récupérer la météo stockée (Celle qui manquait !)
app.get('/weather/:villeId', async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT * FROM donnees_meteo 
             WHERE ville_id = $1 
             AND date_concernee::date >= CURRENT_DATE 
             ORDER BY date_concernee ASC, id DESC`,
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
        const geoUrl = `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=fr`;
        const response = await axios.get(geoUrl);
        const cityName = response.data.city || response.data.locality || "Ville inconnue";

        console.log(`🏙️ Ville détectée : ${cityName}`);
        const villeId = await getOrCreateVille(cityName, lat, lon);

        const checkData = await pool.query(
            "SELECT id FROM donnees_meteo WHERE ville_id = $1 AND date_concernee::date = CURRENT_DATE LIMIT 1",
            [villeId]
        );

        if (checkData.rows.length === 0) {
            console.log(`⚠️ Données obsolètes pour ${cityName} (GPS). Lancement d'un fetch d'urgence !`);
            await fetchAndStoreAllForecasts(villeId, lat, lon);
        }

        res.json({ id: villeId, ville: cityName });

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

app.listen(3000, '0.0.0.0', () => console.log("Serveur multi-sources prêt sur port 3000"));
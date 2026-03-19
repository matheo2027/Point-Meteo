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

// --- Fonctions de traduction pour la route Hourly ---
function mapWeatherApiToWMO(code) {
    if (code === 1000) return 0;
    if (code === 1003) return 1;
    if ([1006, 1009].includes(code)) return 3;
    if ([1030, 1135, 1148].includes(code)) return 45;
    if (code >= 1063 && code <= 1201) return 61;
    if (code >= 1210 && code <= 1225) return 71;
    if (code >= 1240 && code <= 1264) return 80;
    if (code >= 1273 && code <= 1282) return 95;
    return 3;
}

function mapMeteoConceptToWMO(code) {
    if (code === 0) return 0;
    if (code >= 1 && code <= 2) return 1;
    if (code >= 3 && code <= 5) return 3;
    if (code >= 10 && code <= 16) return 61;
    if (code >= 20 && code <= 22) return 71;
    if (code >= 30 && code <= 48) return 80;
    if (code >= 100 && code <= 142) return 95;
    return 3;
}

// ROUTE 5 : Récupérer le "Heure par Heure" en direct pour la MEILLEURE source
app.get('/hourly', async (req, res) => {
    const { lat, lon, source } = req.query;

    if (!lat || !lon || !source) {
        return res.status(400).json({ error: "Paramètres manquants (lat, lon, source)" });
    }

    try {
        let hourlyData = [];
        const now = new Date();

        console.log(`📡 Requête Heure par Heure pour la source gagnante : ${source}`);

        // --- CAS 1 : OPEN-METEO GAGNE ---
        if (source === 'Open-Meteo') {
            const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&hourly=temperature_2m,weathercode&timezone=auto&forecast_days=2`;
            const response = await axios.get(url);
            
            for (let i = 0; i < response.data.hourly.time.length; i++) {
                const hourTime = new Date(response.data.hourly.time[i]);
                if (hourTime >= now && hourlyData.length < 24) {
                    hourlyData.push({
                        time: response.data.hourly.time[i].substring(11, 16),
                        temp: Math.round(response.data.hourly.temperature_2m[i]),
                        code_meteo: response.data.hourly.weathercode[i]
                    });
                }
            }
        } 
        
        // --- CAS 2 : WEATHERAPI GAGNE ---
        else if (source === 'WeatherAPI') {
            const API_KEY = process.env.WEATHER_API_KEY;
            const url = `http://api.weatherapi.com/v1/forecast.json?key=${API_KEY}&q=${lat},${lon}&days=2`;
            const response = await axios.get(url);
            
            const allHours = [
                ...response.data.forecast.forecastday[0].hour,
                ...response.data.forecast.forecastday[1].hour
            ];

            for (const h of allHours) {
                const hourTime = new Date(h.time);
                if (hourTime >= now && hourlyData.length < 24) {
                    hourlyData.push({
                        time: h.time.substring(11, 16),
                        temp: Math.round(h.temp_c),
                        code_meteo: mapWeatherApiToWMO(h.condition.code)
                    });
                }
            }
        } 
        
        // --- CAS 3 : METEO-CONCEPT GAGNE ---
        else if (source === 'Meteo-Concept') {
            const TOKEN = process.env.METEOCONCEPT_API_KEY;
            const url = `https://api.meteo-concept.com/api/forecast/nextHours?token=${TOKEN}&latlng=${lat},${lon}`;
            const response = await axios.get(url);

            for (const h of response.data.forecast) {
                if (hourlyData.length < 8) {
                    hourlyData.push({
                        time: h.datetime.substring(11, 16),
                        temp: Math.round(h.temp2m),
                        code_meteo: mapMeteoConceptToWMO(h.weather)
                    });
                }
            }
        }

        res.json(hourlyData);

    } catch (err) {
        console.error("❌ Erreur Route Hourly :", err.message);
        res.status(500).json({ error: "Impossible de récupérer les données horaires" });
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
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const express = require('express');
const axios = require('axios');
const { getOrCreateVille, pool } = require('./db');
const {
    fetchAndStoreAllForecasts,
    fetchAndStoreAllRealData,
    backfillReferenceRealityForAllCities,
    cleanupLegacyRealData
} = require('./weatherService');
const { execFile } = require('child_process');

const app = express();
app.use(express.json());
app.use((req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-admin-token');

    if (req.method === 'OPTIONS') {
        return res.sendStatus(204);
    }

    next();
});

const REFERENCE_SOURCE = process.env.REFERENCE_SOURCE || 'Reference-Obs';
const REFERENCE_LATENCY_CACHE_TTL_MS = parseInt(
    process.env.REFERENCE_LATENCY_CACHE_TTL_MS || '900000',
    10
);
const SCORE_PER_DEGREE = parseFloat(process.env.SCORE_PER_DEGREE || '6.0');
const KPI_CONFIDENCE_HIGH = parseInt(process.env.KPI_CONFIDENCE_HIGH || '120', 10);
const KPI_CONFIDENCE_MEDIUM = parseInt(process.env.KPI_CONFIDENCE_MEDIUM || '50', 10);
const providerLatencyCache = new Map();
const RELIABILITY_SCRIPT_PATH = path.join(__dirname, 'Comparaison_python', 'analyse_fiabilite.py');
const PYTHON_BIN = process.env.PYTHON_BIN || (process.platform === 'win32' ? 'python' : 'python3');

function runReliabilityAnalysis() {
    return new Promise((resolve, reject) => {
        execFile(PYTHON_BIN, [RELIABILITY_SCRIPT_PATH], { cwd: __dirname }, (error, stdout, stderr) => {
            if (error) {
                return reject(new Error(stderr || error.message));
            }
            resolve(stdout);
        });
    });
}

async function refreshReliabilityInputs() {
    const villes = await pool.query('SELECT id, latitude, longitude FROM villes');

    for (const ville of villes.rows) {
        await fetchAndStoreAllForecasts(ville.id, ville.latitude, ville.longitude);
    }

    for (const ville of villes.rows) {
        await fetchAndStoreAllRealData(ville.id, ville.latitude, ville.longitude);
    }

    return villes.rows.length;
}

function checkAdminToken(req) {
    const expected = process.env.ADMIN_TOKEN;
    if (!expected) return false;
    return req.headers['x-admin-token'] === expected;
}

async function runDailyWeatherMaintenance() {
    const processedCities = await refreshReliabilityInputs();
    const analysisOutput = await runReliabilityAnalysis();

    return {
        processedCities,
        analysisOutput: analysisOutput.trim()
    };
}

async function runForecastRefreshMaintenance() {
    const villes = await pool.query('SELECT id, latitude, longitude FROM villes');

    for (const ville of villes.rows) {
        await fetchAndStoreAllForecasts(ville.id, ville.latitude, ville.longitude);
    }

    return {
        processedCities: villes.rows.length
    };
}

function getCachedProviderLatency(source) {
        const cached = providerLatencyCache.get(source);
        if (!cached) return null;
        if (Date.now() - cached.cachedAt > REFERENCE_LATENCY_CACHE_TTL_MS) {
                providerLatencyCache.delete(source);
                return null;
        }
        return cached.value;
}

function setCachedProviderLatency(source, value) {
        providerLatencyCache.set(source, {
                cachedAt: Date.now(),
                value
        });
}

function computeConfidenceLabel(totalCompared) {
    if (totalCompared >= KPI_CONFIDENCE_HIGH) {
        return { label: 'Elevee', score: 100, threshold: KPI_CONFIDENCE_HIGH };
    }
    if (totalCompared >= KPI_CONFIDENCE_MEDIUM) {
        const span = KPI_CONFIDENCE_HIGH - KPI_CONFIDENCE_MEDIUM || 1;
        const score = 60 + ((totalCompared - KPI_CONFIDENCE_MEDIUM) / span) * 40;
        return { label: 'Moyenne', score: Number(score.toFixed(2)), threshold: KPI_CONFIDENCE_MEDIUM };
    }
    const score = KPI_CONFIDENCE_MEDIUM === 0
        ? 0
        : (totalCompared / KPI_CONFIDENCE_MEDIUM) * 60;
    return { label: 'Faible', score: Number(score.toFixed(2)), threshold: KPI_CONFIDENCE_MEDIUM };
}

function buildProviderProbeUrl(source, lat, lon) {
    if (source === 'Open-Meteo') {
        return `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=temperature_2m_max&timezone=auto&forecast_days=1`;
    }
    if (source === 'WeatherAPI') {
        return `https://api.weatherapi.com/v1/forecast.json?key=${process.env.WEATHER_API_KEY}&q=${lat},${lon}&days=1`;
    }
    if (source === 'Meteo-Concept') {
        return `https://api.meteo-concept.com/api/forecast/daily?token=${process.env.METEOCONCEPT_API_KEY}&latlng=${lat},${lon}`;
    }
    return null;
}

async function measureProviderLatencyMs(source, lat, lon, samples = 3) {
    const url = buildProviderProbeUrl(source, lat, lon);
    if (!url) return null;

    const durations = [];
    for (let i = 0; i < samples; i++) {
        const startedAt = Date.now();
        try {
            await axios.get(url, { timeout: 8000 });
            durations.push(Date.now() - startedAt);
        } catch (_err) {
            continue;
        }
    }

    if (durations.length === 0) return null;

    const total = durations.reduce((a, b) => a + b, 0);
    return {
        avg: Number((total / durations.length).toFixed(2)),
        min: Math.min(...durations),
        max: Math.max(...durations),
        samples: durations.length
    };
}

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
            // Vérifier si on a des données fraîches pour AUJOURD'HUI
            const checkData = await pool.query(
                "SELECT id FROM donnees_meteo WHERE ville_id = $1 AND date_concernee::date = CURRENT_DATE LIMIT 1",
                [villeExistante.id]
            );

            if (checkData.rows.length === 0) {
                await fetchAndStoreAllForecasts(villeExistante.id, villeExistante.latitude, villeExistante.longitude);
            }

            return res.json({ 
                id: villeExistante.id, 
                ville: villeExistante.nom, 
                coords: { latitude: villeExistante.latitude, longitude: villeExistante.longitude } 
            });
        }

        const geoUrl = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(nomVille)}&count=1&language=fr&format=json`;
        const geoRes = await axios.get(geoUrl);

        if (!geoRes.data.results) {
            return res.status(404).json({ error: "Ville non trouvée" });
        }

        const { latitude, longitude, name } = geoRes.data.results[0];
        const villeId = await getOrCreateVille(name, latitude, longitude);

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

// ROUTE 3 : Récupérer les scores globaux (toutes villes) par source
app.get('/scores/global', async (_req, res) => {
    try {
        const result = await pool.query(
            `WITH daily_errors AS (
                SELECT
                    p.source,
                    p.date_concernee::date AS day,
                    AVG(ABS(p.temp - r.temp)) AS mae
                FROM donnees_meteo p
                JOIN donnees_meteo r
                    ON r.ville_id = p.ville_id
                    AND r.date_concernee::date = p.date_concernee::date
                    AND r.type = 'realite'
                    AND r.source = $1
                WHERE p.type = 'prevision'
                  AND p.source <> $1
                  AND p.date_concernee::date IN (
                      CURRENT_DATE - INTERVAL '1 day',
                      CURRENT_DATE - INTERVAL '2 day'
                  )
                GROUP BY p.source, p.date_concernee::date
            ),
            trend AS (
                SELECT
                    source,
                    MAX(CASE WHEN day = CURRENT_DATE - INTERVAL '1 day'
                        THEN GREATEST(0, 100 - (mae * $2)) END) AS score_j1,
                    MAX(CASE WHEN day = CURRENT_DATE - INTERVAL '2 day'
                        THEN GREATEST(0, 100 - (mae * $2)) END) AS score_j2
                FROM daily_errors
                GROUP BY source
            )
            SELECT
                sf.source,
                ROUND(AVG(sf.score_fiabilite)::numeric, 2) AS score_moyen,
                COUNT(*) AS nb_villes,
                ROUND((t.score_j1 - t.score_j2)::numeric, 2) AS trend_delta,
                CASE
                    WHEN t.score_j1 IS NULL OR t.score_j2 IS NULL THEN 'flat'
                    WHEN t.score_j1 > t.score_j2 THEN 'up'
                    WHEN t.score_j1 < t.score_j2 THEN 'down'
                    ELSE 'flat'
                END AS trend_direction
            FROM scores_fiabilite sf
            LEFT JOIN trend t ON t.source = sf.source
            GROUP BY sf.source, t.score_j1, t.score_j2
            ORDER BY score_moyen DESC`,
            [REFERENCE_SOURCE, SCORE_PER_DEGREE]
        );
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ROUTE 4 : Récupérer les scores de fiabilité d'une ville
app.get('/scores/:villeId', async (req, res) => {
    try {
        const result = await pool.query(
            `WITH daily_errors AS (
                SELECT
                    p.source,
                    p.date_concernee::date AS day,
                    AVG(ABS(p.temp - r.temp)) AS mae
                FROM donnees_meteo p
                JOIN donnees_meteo r
                    ON r.ville_id = p.ville_id
                    AND r.date_concernee::date = p.date_concernee::date
                    AND r.type = 'realite'
                    AND r.source = $1
                WHERE p.type = 'prevision'
                  AND p.ville_id = $3
                  AND p.source <> $1
                  AND p.date_concernee::date IN (
                      CURRENT_DATE - INTERVAL '1 day',
                      CURRENT_DATE - INTERVAL '2 day'
                  )
                GROUP BY p.source, p.date_concernee::date
            ),
            trend AS (
                SELECT
                    source,
                    MAX(CASE WHEN day = CURRENT_DATE - INTERVAL '1 day'
                        THEN GREATEST(0, 100 - (mae * $2)) END) AS score_j1,
                    MAX(CASE WHEN day = CURRENT_DATE - INTERVAL '2 day'
                        THEN GREATEST(0, 100 - (mae * $2)) END) AS score_j2
                FROM daily_errors
                GROUP BY source
            )
            SELECT
                sf.*, 
                ROUND((t.score_j1 - t.score_j2)::numeric, 2) AS trend_delta,
                CASE
                    WHEN t.score_j1 IS NULL OR t.score_j2 IS NULL THEN 'flat'
                    WHEN t.score_j1 > t.score_j2 THEN 'up'
                    WHEN t.score_j1 < t.score_j2 THEN 'down'
                    ELSE 'flat'
                END AS trend_direction
            FROM scores_fiabilite sf
            LEFT JOIN trend t ON t.source = sf.source
            WHERE sf.ville_id = $3`,
            [REFERENCE_SOURCE, SCORE_PER_DEGREE, req.params.villeId]
        );
        res.json(result.rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ROUTE 5 : Récupérer les coordonnées gps
app.get('/search-coords', async (req, res) => {
    const { lat, lon } = req.query;
    try {
        const geoUrl = `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=fr`;
        const response = await axios.get(geoUrl);
        const cityName = response.data.city || response.data.locality || "Ville inconnue";

        if (cityName === 'Ville inconnue') {
            return res.status(404).json({ error: 'Ville introuvable' });
        }

        const villeId = await getOrCreateVille(cityName, lat, lon);

        const checkData = await pool.query(
            "SELECT id FROM donnees_meteo WHERE ville_id = $1 AND date_concernee::date = CURRENT_DATE LIMIT 1",
            [villeId]
        );

        if (checkData.rows.length === 0) {
            await fetchAndStoreAllForecasts(villeId, lat, lon);
        }

        res.json({ id: villeId, ville: cityName });

    } catch (err) {
        console.error("❌ Erreur API Geocoding :", err.message);
        res.status(500).json({ error: "Impossible de localiser la ville" });
    }
});

// ROUTE 6 : KPI détaillés d'un provider
app.get('/provider-kpi/:source', async (req, res) => {
    const source = decodeURIComponent(req.params.source);

    try {
        const kpiResult = await pool.query(
            `WITH matched AS (
                SELECT
                    p.ville_id,
                    ABS(p.temp - r.temp) AS abs_error
                FROM donnees_meteo p
                JOIN donnees_meteo r
                    ON r.ville_id = p.ville_id
                    AND r.date_concernee::date = p.date_concernee::date
                    AND r.type = 'realite'
                    AND r.source = $1
                WHERE p.type = 'prevision'
                  AND p.source = $2
                  AND p.date_concernee::date >= CURRENT_DATE - INTERVAL '120 days'
            ),
            score_stats AS (
                SELECT
                    AVG(score_fiabilite) AS avg_score
                FROM scores_fiabilite
                WHERE source = $2
            ),
            score_city_stats AS (
                SELECT
                    COUNT(DISTINCT ville_id) AS score_cities
                FROM scores_fiabilite
                WHERE source = $2
            )
            SELECT
                $2::text AS source,
                COUNT(*)::int AS total_compared,
                COUNT(*) FILTER (WHERE abs_error <= 1.0)::int AS exact_predictions,
                ROUND(COALESCE(
                    (COUNT(*) FILTER (WHERE abs_error <= 1.0)::numeric * 100)
                    / NULLIF(COUNT(*), 0),
                    0
                ), 2) AS exact_rate,
                ROUND(COALESCE(AVG(abs_error), 0)::numeric, 2) AS mae,
                ROUND(COALESCE(SQRT(AVG(POWER(abs_error, 2))), 0)::numeric, 2) AS rmse,
                COALESCE((SELECT score_cities FROM score_city_stats), 0)::int AS compared_cities,
                ROUND(COALESCE((SELECT avg_score FROM score_stats), 0)::numeric, 2) AS avg_reliability_score
            FROM matched;`,
            [REFERENCE_SOURCE, source]
        );

        const hasDateEnregistrement = await pool.query(
            `SELECT EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_name = 'donnees_meteo'
                  AND column_name = 'date_enregistrement'
            ) AS has_column;`
        );

        let freshnessLatencyMinutes = null;
        if (hasDateEnregistrement.rows[0].has_column) {
            const latencyResult = await pool.query(
                `SELECT ROUND(
                    EXTRACT(EPOCH FROM (NOW() - MAX(date_enregistrement)))::numeric / 60,
                    2
                ) AS freshness_latency_minutes
                 FROM donnees_meteo
                 WHERE source = $1
                   AND type = 'prevision';`,
                [source]
            );
            freshnessLatencyMinutes = latencyResult.rows[0].freshness_latency_minutes;
        }

        let apiLatency = null;
        const cachedLatency = getCachedProviderLatency(source);
        if (cachedLatency) {
            apiLatency = cachedLatency;
        } else {
            const probeCityResult = await pool.query(
                `SELECT latitude, longitude
                 FROM villes
                 ORDER BY id DESC
                 LIMIT 1`
            );

            if (probeCityResult.rows.length > 0) {
                const probeCity = probeCityResult.rows[0];
                try {
                    apiLatency = await measureProviderLatencyMs(
                        source,
                        probeCity.latitude,
                        probeCity.longitude,
                        3
                    );
                    if (apiLatency) {
                        setCachedProviderLatency(source, apiLatency);
                    }
                } catch (_err) {
                    apiLatency = null;
                }
            }
        }

        const payload = {
            ...kpiResult.rows[0],
            freshness_latency_minutes: freshnessLatencyMinutes,
            api_latency_ms_avg: apiLatency?.avg ?? null,
            api_latency_ms_min: apiLatency?.min ?? null,
            api_latency_ms_max: apiLatency?.max ?? null,
            api_latency_samples: apiLatency?.samples ?? 0,
            confidence: computeConfidenceLabel(parseInt(kpiResult.rows[0]?.total_compared ?? '0', 10)),
            confidence_thresholds: {
                medium: KPI_CONFIDENCE_MEDIUM,
                high: KPI_CONFIDENCE_HIGH
            }
        };

        res.json(payload);
    } catch (err) {
        res.status(500).json({ error: err.message });
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

function toYmd(dateValue) {
    return new Date(dateValue).toISOString().split('T')[0];
}

function computeRainfallStats(seriesByDate) {
    const values = Object.values(seriesByDate).filter(v => v != null);
    if (values.length === 0) {
        return {
            points: 0,
            total_mm: 0,
            average_mm: 0,
            rainy_days: 0,
            max_mm: 0
        };
    }

    const total = values.reduce((acc, v) => acc + v, 0);
    const rainyDays = values.filter(v => v >= 0.1).length;
    const max = Math.max(...values);

    return {
        points: values.length,
        total_mm: Number(total.toFixed(2)),
        average_mm: Number((total / values.length).toFixed(2)),
        rainy_days: rainyDays,
        max_mm: Number(max.toFixed(2))
    };
}

function computeDailySpread(days) {
    const spreads = [];
    for (const d of days) {
        const vals = [d.open_meteo_mm, d.weatherapi_mm, d.meteoconcept_mm]
            .filter(v => v != null);
        if (vals.length < 2) continue;
        spreads.push(Math.max(...vals) - Math.min(...vals));
    }

    if (spreads.length === 0) {
        return { average_spread_mm: 0, max_spread_mm: 0, compared_days: 0 };
    }

    const avg = spreads.reduce((a, b) => a + b, 0) / spreads.length;
    return {
        average_spread_mm: Number(avg.toFixed(2)),
        max_spread_mm: Number(Math.max(...spreads).toFixed(2)),
        compared_days: spreads.length
    };
}

async function fetchRainfallStudy(lat, lon) {
    const openMeteoUrl = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=precipitation_sum&timezone=auto&forecast_days=7`;
    const weatherApiUrl = `https://api.weatherapi.com/v1/forecast.json?key=${process.env.WEATHER_API_KEY}&q=${lat},${lon}&days=7`;
    const meteoConceptUrl = `https://api.meteo-concept.com/api/forecast/daily?token=${process.env.METEOCONCEPT_API_KEY}&latlng=${lat},${lon}`;

    const [omRes, waRes, mcRes] = await Promise.all([
        axios.get(openMeteoUrl),
        axios.get(weatherApiUrl),
        axios.get(meteoConceptUrl)
    ]);

    const openMeteo = {};
    for (let i = 0; i < omRes.data.daily.time.length; i++) {
        const date = toYmd(omRes.data.daily.time[i]);
        openMeteo[date] = Number((omRes.data.daily.precipitation_sum[i] ?? 0).toFixed(2));
    }

    const weatherApi = {};
    for (const d of waRes.data.forecast.forecastday) {
        const date = toYmd(d.date);
        weatherApi[date] = Number((d.day.totalprecip_mm ?? 0).toFixed(2));
    }

    const meteoConcept = {};
    for (const d of mcRes.data.forecast.slice(0, 7)) {
        const date = toYmd(d.datetime);
        meteoConcept[date] = Number((d.rr10 ?? d.rr1 ?? 0).toFixed(2));
    }

    const allDates = Array.from(
        new Set([...Object.keys(openMeteo), ...Object.keys(weatherApi), ...Object.keys(meteoConcept)])
    ).sort();

    const daily = allDates.map(date => ({
        date,
        open_meteo_mm: openMeteo[date] ?? null,
        weatherapi_mm: weatherApi[date] ?? null,
        meteoconcept_mm: meteoConcept[date] ?? null
    }));

    return {
        providers: {
            'Open-Meteo': computeRainfallStats(openMeteo),
            'WeatherAPI': computeRainfallStats(weatherApi),
            'Meteo-Concept': computeRainfallStats(meteoConcept)
        },
        consistency: computeDailySpread(daily),
        daily
    };
}

// ROUTE 7 : Etude comparative pluie (Rainfall) pour une ville
app.get('/rainfall-study/:villeId', async (req, res) => {
    try {
        const city = await pool.query(
            'SELECT id, nom, latitude, longitude FROM villes WHERE id = $1',
            [req.params.villeId]
        );

        if (city.rows.length === 0) {
            return res.status(404).json({ error: 'Ville introuvable' });
        }

        const v = city.rows[0];
        const study = await fetchRainfallStudy(v.latitude, v.longitude);

        res.json({
            ville: { id: v.id, nom: v.nom, latitude: v.latitude, longitude: v.longitude },
            horizon_days: 7,
            unit: 'mm',
            ...study
        });
    } catch (err) {
        console.error('❌ Erreur Rainfall Study :', err.message);
        res.status(500).json({ error: 'Impossible de calculer l etude comparative pluie' });
    }
});

// ROUTE 5 : Récupérer le "Heure par Heure" en direct pour la MEILLEURE source
app.get('/hourly', async (req, res) => {
    const { lat, lon, source } = req.query;

    if (!lat || !lon || !source) {
        return res.status(400).json({ error: "Paramètres manquants (lat, lon, source)" });
    }

    try {
        let hourlyData = [];
        const now = new Date();

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
            const url = `https://api.weatherapi.com/v1/forecast.json?key=${API_KEY}&q=${lat},${lon}&days=2`;
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

// ROUTE 6 : Rebuild complet de la fiabilité (nettoyage + backfill + analyse)
app.post('/admin/reliability/rebuild', async (req, res) => {
        if (!process.env.ADMIN_TOKEN) {
            return res.status(503).json({
                error: 'ADMIN_TOKEN non configuré. Route admin désactivée.'
            });
        }

        if (!checkAdminToken(req)) {
            return res.status(403).json({ error: 'Accès non autorisé' });
        }

    try {
        const refreshedCities = await refreshReliabilityInputs();
        const deletedRows = await cleanupLegacyRealData();
        const processedCities = await backfillReferenceRealityForAllCities();
        const analysisOutput = await runReliabilityAnalysis();

        res.json({
            status: 'ok',
            refreshedCities,
            deletedLegacyRealiteRows: deletedRows,
            backfilledCities: processedCities,
            analysisOutput: analysisOutput.trim()
        });
    } catch (err) {
        console.error('❌ Erreur rebuild fiabilité :', err.message);
        res.status(500).json({ error: err.message });
    }
});

// ROUTE CRON EXTERNE : appelée par GitHub Actions / cron-job.org
app.post('/api/trigger-daily-weather', async (req, res) => {
    if (!process.env.ADMIN_TOKEN) {
        return res.status(503).json({
            error: 'ADMIN_TOKEN non configuré. Route désactivée.'
        });
    }

    if (!checkAdminToken(req)) {
        return res.status(403).json({ error: 'Accès non autorisé' });
    }

    try {
        const result = await runDailyWeatherMaintenance();
        res.json({
            status: 'ok',
            ...result
        });
    } catch (error) {
        console.error('❌ Erreur maintenance météo ENTIÈRE :', error); 
        
        const errorMessage = error instanceof Error ? error.message : JSON.stringify(error) || String(error);
        
        res.status(500).json({ error: errorMessage });
    }
});

// ROUTE CRON EXTERNE : refresh des prévisions uniquement
app.post('/api/trigger-forecast-refresh', async (req, res) => {
    if (!process.env.ADMIN_TOKEN) {
        return res.status(503).json({
            error: 'ADMIN_TOKEN non configuré. Route désactivée.'
        });
    }

    if (!checkAdminToken(req)) {
        return res.status(403).json({ error: 'Accès non autorisé' });
    }

    try {
        const result = await runForecastRefreshMaintenance();
        res.json({
            status: 'ok',
            ...result
        });
    } catch (error) {
        console.error('❌ Erreur refresh prévisions :', error);

        const errorMessage = error instanceof Error ? error.message : JSON.stringify(error) || String(error);

        res.status(500).json({ error: errorMessage });
    }
});

const port = process.env.PORT || 3000;
app.listen(port, '0.0.0.0');
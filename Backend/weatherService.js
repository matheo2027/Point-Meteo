const { pool } = require('./db');
// Import des adaptateurs
const sources = [
    require('./services/openMeteoService'),
    require('./services/weatherApiService'),
    require('./services/meteoConceptService')
];

// Fonction générique pour sauvegarder en SQL
async function saveMeteo(villeId, source, date, temp, type) {
    await pool.query(
        `INSERT INTO donnees_meteo (ville_id, source, temp, date_concernee, type)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (ville_id, source, date_concernee, type) 
         DO UPDATE SET temp = EXCLUDED.temp`,
        [villeId, source, temp, date, type]
    );
}

// COLLECTE DES PRÉVISIONS
async function fetchAndStoreAllForecasts(villeId, lat, lon) {
    for (const source of sources) {
        try {
            const data = await source.fetchForecast(lat, lon);
            for (const item of data) {
                await saveMeteo(villeId, source.name, item.date, item.temp, 'prevision');
            }
            console.log(`   -> ${source.name} : OK`);
            // RATE LIMIT : Pause de 500ms entre chaque API
            await new Promise(res => setTimeout(res, 500));
        } catch (err) {
            console.error(`   ! Erreur ${source.name}:`, err.message);
        }
    }
}

// COLLECTE DE L'HISTORIQUE (HIER)
async function fetchAndStoreAllRealData(villeId, lat, lon) {
    for (const source of sources) {
        try {
            const data = await source.fetchHistory(lat, lon);
            await saveMeteo(villeId, source.name, data.date, data.temp, 'realite');
            console.log(`   -> ${source.name} (Histoire) : OK`);
        } catch (err) {
            console.error(`   ! Erreur Histoire ${source.name}:`, err.message);
        }
    }
}

module.exports = { fetchAndStoreAllForecasts, fetchAndStoreAllRealData };
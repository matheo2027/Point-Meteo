const { pool } = require('./db');

const sources = [
    require('./services/openMeteoService'),
    require('./services/weatherApiService'),
    require('./services/meteoConceptService')
];

// On ajoute code_meteo dans la requête SQL !
async function saveMeteo(villeId, source, date, temp, code_meteo, type) {
    await pool.query(
        `INSERT INTO donnees_meteo (ville_id, source, temp, code_meteo, date_concernee, type)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (ville_id, source, date_concernee, type) 
         DO UPDATE SET temp = EXCLUDED.temp, code_meteo = EXCLUDED.code_meteo`,
        [villeId, source, temp, code_meteo || 0, date, type]
    );
}

async function fetchAndStoreAllForecasts(villeId, lat, lon) {
    for (const source of sources) {
        try {
            const data = await source.fetchForecast(lat, lon);
            for (const item of data) {
                // On passe le code_meteo à la fonction de sauvegarde
                await saveMeteo(villeId, source.name, item.date, item.temp, item.code_meteo, 'prevision');
            }
            console.log(`   -> ${source.name} : OK`);
            await new Promise(res => setTimeout(res, 500));
        } catch (err) {
            console.error(`   ! Erreur ${source.name}:`, err.message);
        }
    }
}

async function fetchAndStoreAllRealData(villeId, lat, lon) {
    for (const source of sources) {
        try {
            const data = await source.fetchHistory(lat, lon);
            // On passe le code_meteo à la fonction de sauvegarde
            await saveMeteo(villeId, source.name, data.date, data.temp, data.code_meteo, 'realite');
            console.log(`   -> ${source.name} (Histoire) : OK`);
        } catch (err) {
            console.error(`   ! Erreur Histoire ${source.name}:`, err.message);
        }
    }
}

module.exports = { fetchAndStoreAllForecasts, fetchAndStoreAllRealData };
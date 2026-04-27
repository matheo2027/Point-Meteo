const { pool } = require('./db');

const sources = [
    require('./services/openMeteoService'),
    require('./services/weatherApiService'),
    require('./services/meteoConceptService')
];
const referenceObservationService = require('./services/referenceObservationService');

// On ajoute code_meteo dans la requête SQL !
async function saveMeteo(villeId, source, date, temp, code_meteo, type) {
    await pool.query(
        `INSERT INTO donnees_meteo (ville_id, source, temp, code_meteo, date_concernee, type)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (ville_id, source, date_concernee, type) 
         DO UPDATE SET
           temp = EXCLUDED.temp,
           code_meteo = EXCLUDED.code_meteo,
           date_enregistrement = NOW()`,
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
            await new Promise(res => setTimeout(res, 500));
        } catch (err) {
            console.error(`   ! Erreur ${source.name}:`, err.message);
        }
    }
}

async function fetchAndStoreAllRealData(villeId, lat, lon) {
    try {
        const data = await referenceObservationService.fetchHistory(lat, lon);
        await saveMeteo(
            villeId,
            referenceObservationService.name,
            data.date,
            data.temp,
            data.code_meteo,
            'realite'
        );
    } catch (err) {
        console.error(`   ! Erreur Référence ${referenceObservationService.name}:`, err.message);
    }
}

async function backfillReferenceRealityForAllCities() {
    const villes = await pool.query("SELECT id, latitude, longitude FROM villes");
    for (const v of villes.rows) {
        await fetchAndStoreAllRealData(v.id, v.latitude, v.longitude);
    }
    return villes.rows.length;
}

async function cleanupLegacyRealData() {
    const result = await pool.query(
        `DELETE FROM donnees_meteo
         WHERE type = 'realite' AND source <> $1`,
        [referenceObservationService.name]
    );
    return result.rowCount;
}

module.exports = {
    fetchAndStoreAllForecasts,
    fetchAndStoreAllRealData,
    backfillReferenceRealityForAllCities,
    cleanupLegacyRealData
};
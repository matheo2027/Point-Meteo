const axios = require('axios');
const TOKEN = process.env.METEOCONCEPT_API_KEY;

// Fonction pour traduire les codes Meteo-Concept en standard WMO
function mapToWMO(code) {
    if (code === 0) return 0; // Soleil
    if (code >= 1 && code <= 2) return 1; // Eclaircies
    if (code >= 3 && code <= 5) return 3; // Nuageux
    if (code >= 10 && code <= 16) return 61; // Pluie
    if (code >= 20 && code <= 22) return 71; // Neige
    if (code >= 30 && code <= 48) return 80; // Averses
    if (code >= 100 && code <= 142) return 95; // Orages
    return 3;
}

async function fetchForecast(lat, lon) {
    const url = `https://api.meteo-concept.com/api/forecast/daily?token=${TOKEN}&latlng=${lat},${lon}`;
    const res = await axios.get(url);
    
    return res.data.forecast.slice(0, 7).map(day => ({
        date: day.datetime.substring(0, 10),
        temp: day.tmax,
        code_meteo: mapToWMO(day.weather) // On traduit et on récupère !
    }));
}

async function fetchHistory(lat, lon) {
    const url = `https://api.meteo-concept.com/api/forecast/daily?token=${TOKEN}&latlng=${lat},${lon}`;
    const res = await axios.get(url);
    const todayData = res.data.forecast[0];

    return {
        date: todayData.datetime.substring(0, 10),
        temp: todayData.tmax,
        code_meteo: mapToWMO(todayData.weather)
    };
}

module.exports = { name: 'Meteo-Concept', fetchForecast, fetchHistory };
const axios = require('axios');
const TOKEN = process.env.METEOCONCEPT_API_KEY;

async function fetchForecast(lat, lon) {
    // API Meteo-Concept : Prévisions quotidiennes pour les 7 prochains jours
    const url = `https://api.meteo-concept.com/api/forecast/daily?token=${TOKEN}&latlng=${lat},${lon}`;
    
    const res = await axios.get(url);
    
    // On normalise vers notre format standard
    return res.data.forecast.slice(0, 7).map(day => ({
        date: day.datetime.substring(0, 10), // Format ISO 2026-02-09
        temp: day.tmax
    }));
}

async function fetchHistory(lat, lon) {
    // Meteo-Concept est surtout axé prévisions. 
    // Pour l'historique, on va récupérer les prévisions du jour J (index 0)
    const url = `https://api.meteo-concept.com/api/forecast/daily?token=${TOKEN}&latlng=${lat},${lon}`;
    
    const res = await axios.get(url);
    const todayData = res.data.forecast[0];

    return {
        date: todayData.datetime.substring(0, 10),
        temp: todayData.tmax
    };
}

module.exports = { name: 'Meteo-Concept', fetchForecast, fetchHistory };
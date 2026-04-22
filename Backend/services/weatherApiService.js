const axios = require('axios');
const API_KEY = process.env.WEATHER_API_KEY;

// Fonction pour traduire les codes WeatherAPI en standard WMO (Flutter)
function mapToWMO(code) {
    if (code === 1000) return 0; // Soleil
    if (code === 1003) return 1; // Peu nuageux
    if ([1006, 1009].includes(code)) return 3; // Nuageux
    if ([1030, 1135, 1148].includes(code)) return 45; // Brouillard
    if (code >= 1063 && code <= 1201) return 61; // Pluie
    if (code >= 1210 && code <= 1225) return 71; // Neige
    if (code >= 1240 && code <= 1264) return 80; // Averses
    if (code >= 1273 && code <= 1282) return 95; // Orages
    return 3; // Nuage par défaut
}

async function fetchForecast(lat, lon) {
    const url = `https://api.weatherapi.com/v1/forecast.json?key=${API_KEY}&q=${lat},${lon}&days=7`;
    const res = await axios.get(url);
    return res.data.forecast.forecastday.map(d => ({
        date: d.date,
        temp: d.day.maxtemp_c,
        code_meteo: mapToWMO(d.day.condition.code) // On traduit et on récupère !
    }));
}

async function fetchHistory(lat, lon) {
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
    const url = `https://api.weatherapi.com/v1/history.json?key=${API_KEY}&q=${lat},${lon}&dt=${yesterday}`;
    const res = await axios.get(url);
    const day = res.data.forecast.forecastday[0];
    return { 
        date: day.date, 
        temp: day.day.maxtemp_c,
        code_meteo: mapToWMO(day.day.condition.code)
    };
}

module.exports = { name: 'WeatherAPI', fetchForecast, fetchHistory };
const axios = require('axios');

async function fetchForecast(lat, lon) {
    // AJOUT : on demande le 'weathercode' en plus de la température dans l'URL
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=temperature_2m_max,weathercode&timezone=auto`;
    const res = await axios.get(url);
    
    return res.data.daily.time.map((date, i) => ({
        date,
        temp: res.data.daily.temperature_2m_max[i],
        code_meteo: res.data.daily.weathercode[i] // On récupère le code !
    }));
}

async function fetchHistory(lat, lon) {
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
    const url = `https://archive-api.open-meteo.com/v1/archive?latitude=${lat}&longitude=${lon}&start_date=${yesterday}&end_date=${yesterday}&daily=temperature_2m_max,weathercode&timezone=auto`;
    const res = await axios.get(url);
    
    return { 
        date: yesterday, 
        temp: res.data.daily.temperature_2m_max[0],
        code_meteo: res.data.daily.weathercode[0] // On récupère le code !
    };
}

module.exports = { name: 'Open-Meteo', fetchForecast, fetchHistory };
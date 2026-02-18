const axios = require('axios');

async function fetchForecast(lat, lon) {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=temperature_2m_max&timezone=auto`;
    const res = await axios.get(url);
    return res.data.daily.time.map((date, i) => ({
        date,
        temp: res.data.daily.temperature_2m_max[i]
    }));
}

async function fetchHistory(lat, lon) {
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
    const url = `https://archive-api.open-meteo.com/v1/archive?latitude=${lat}&longitude=${lon}&start_date=${yesterday}&end_date=${yesterday}&daily=temperature_2m_max&timezone=auto`;
    const res = await axios.get(url);
    return { date: yesterday, temp: res.data.daily.temperature_2m_max[0] };
}

module.exports = { name: 'Open-Meteo', fetchForecast, fetchHistory };
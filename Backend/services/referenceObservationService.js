const axios = require('axios');

// Source indépendante de vérité terrain (réanalyse/archives)
const REFERENCE_NAME = 'Reference-Obs';
const REFERENCE_TIMEZONE = process.env.REFERENCE_TIMEZONE || 'Europe/Paris';

function getYesterdayInTimeZone(timeZone) {
    const parts = new Intl.DateTimeFormat('en-CA', {
        timeZone,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit'
    }).formatToParts(new Date());

    const year = Number(parts.find(part => part.type === 'year')?.value);
    const month = Number(parts.find(part => part.type === 'month')?.value);
    const day = Number(parts.find(part => part.type === 'day')?.value);
    return new Date(Date.UTC(year, month - 1, day) - 86400000)
        .toISOString()
        .split('T')[0];
}

async function fetchHistory(lat, lon) {
    const yesterday = getYesterdayInTimeZone(REFERENCE_TIMEZONE);
    const url = `https://archive-api.open-meteo.com/v1/archive?latitude=${lat}&longitude=${lon}&start_date=${yesterday}&end_date=${yesterday}&daily=temperature_2m_max,weathercode&timezone=${encodeURIComponent(REFERENCE_TIMEZONE)}`;
    const res = await axios.get(url);

    return {
        date: yesterday,
        temp: res.data.daily.temperature_2m_max[0],
        code_meteo: res.data.daily.weathercode[0]
    };
}

module.exports = { name: REFERENCE_NAME, fetchHistory };

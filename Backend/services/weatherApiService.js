const axios = require('axios');
const API_KEY = process.env.WEATHER_API_KEY;

async function fetchForecast(lat, lon) {
    const url = `http://api.weatherapi.com/v1/forecast.json?key=${API_KEY}&q=${lat},${lon}&days=7`;
    const res = await axios.get(url);
    return res.data.forecast.forecastday.map(d => ({
        date: d.date,
        temp: d.day.maxtemp_c
    }));
}

async function fetchHistory(lat, lon) {
    const yesterday = new Date(Date.now() - 86400000).toISOString().split('T')[0];
    const url = `http://api.weatherapi.com/v1/history.json?key=${API_KEY}&q=${lat},${lon}&dt=${yesterday}`;
    const res = await axios.get(url);
    const day = res.data.forecast.forecastday[0];
    return { date: day.date, temp: day.day.maxtemp_c };
}

module.exports = { name: 'WeatherAPI', fetchForecast, fetchHistory };
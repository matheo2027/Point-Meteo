const axios = require('axios');
const { pool } = require('./db');

const fetchAndStoreForecast = async (villeId, lat, lon) => {
  // --- SOURCE 1 : OPEN-METEO ---
  try {
    const urlOM = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&daily=temperature_2m_max&timezone=auto`;
    const resOM = await axios.get(urlOM);
    const datesOM = resOM.data.daily.time;
    const tempsOM = resOM.data.daily.temperature_2m_max;

    for (let i = 0; i < 5; i++) {
      await pool.query(
        `INSERT INTO donnees_meteo (ville_id, source, temp, date_concernee, type) 
         VALUES ($1, $2, $3, $4, $5)`,
        [villeId, 'Open-Meteo', tempsOM[i], datesOM[i], 'prevision']
      );
    }
    console.log("✅ 5 jours archivés pour Open-Meteo");
  } catch (err) { console.error("Erreur Open-Meteo:", err.message); }

  // --- SOURCE 2 : WEATHERAPI ---
  try {
    const apiKey = process.env.WEATHER_API_KEY;
    const urlWAPI = `http://api.weatherapi.com/v1/forecast.json?key=${apiKey}&q=${lat},${lon}&days=5&aqi=no&alerts=no`;
    const resWAPI = await axios.get(urlWAPI);
    
    const forecastDays = resWAPI.data.forecast.forecastday;

    for (let i = 0; i < forecastDays.length; i++) {
      await pool.query(
        `INSERT INTO donnees_meteo (ville_id, source, temp, date_concernee, type) 
         VALUES ($1, $2, $3, $4, $5)`,
        [villeId, 'WeatherAPI', forecastDays[i].day.maxtemp_c, forecastDays[i].date, 'prevision']
      );
    }
    console.log("✅ 5 jours archivés pour WeatherAPI");
  } catch (err) { console.error("Erreur WeatherAPI:", err.message); }
};

module.exports = { fetchAndStoreForecast };
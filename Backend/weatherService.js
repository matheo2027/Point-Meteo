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
      // Utilisation de ON CONFLICT pour éviter les doublons
      await pool.query(
        `INSERT INTO donnees_meteo (ville_id, source, temp, date_concernee, type) 
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT ON CONSTRAINT unique_prevision 
         DO UPDATE SET temp = EXCLUDED.temp`,
        [villeId, 'Open-Meteo', tempsOM[i], datesOM[i], 'prevision']
      );
    }
    console.log("Données Open-Meteo mises à jour (sans doublons)");
  } catch (err) { console.error("Erreur Open-Meteo:", err.message); }

  // --- SOURCE 2 : WEATHERAPI ---
  try {
    const apiKey = process.env.WEATHER_API_KEY;
    const urlWAPI = `http://api.weatherapi.com/v1/forecast.json?key=${apiKey}&q=${lat},${lon}&days=5&aqi=no&alerts=no`;
    const resWAPI = await axios.get(urlWAPI);
    
    const forecastDays = resWAPI.data.forecast.forecastday;

    for (let i = 0; i < forecastDays.length; i++) {
      // Utilisation de ON CONFLICT pour éviter les doublons
      await pool.query(
        `INSERT INTO donnees_meteo (ville_id, source, temp, date_concernee, type) 
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT ON CONSTRAINT unique_prevision 
         DO UPDATE SET temp = EXCLUDED.temp`,
        [villeId, 'WeatherAPI', forecastDays[i].day.maxtemp_c, forecastDays[i].date, 'prevision']
      );
    }
    console.log("Données WeatherAPI mises à jour (sans doublons)");
  } catch (err) { console.error("Erreur WeatherAPI:", err.message); }
};

// Fonction pour récupérer la température réelle d'hier
const fetchAndStoreRealData = async (villeId, lat, lon) => {
  try {
    const hier = new Date();
    hier.setDate(hier.getDate() - 1);
    const dateHier = hier.toISOString().split('T')[0];

    const url = `https://archive-api.open-meteo.com/v1/archive?latitude=${lat}&longitude=${lon}&start_date=${dateHier}&end_date=${dateHier}&daily=temperature_2m_max&timezone=auto`;
    const response = await axios.get(url);
    
    const tempReelle = response.data.daily.temperature_2m_max[0];

    // ON CONFLICT fonctionne aussi pour la réalité (Source 'REALITE')
    await pool.query(
      `INSERT INTO donnees_meteo (ville_id, source, temp, date_concernee, type) 
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT ON CONSTRAINT unique_prevision 
       DO UPDATE SET temp = EXCLUDED.temp`,
      [villeId, 'REALITE', tempReelle, dateHier, 'observation']
    );
    console.log(`Réalité vérifiée pour hier (${dateHier}) : ${tempReelle}°C`);
    
  } catch (error) {
    console.error("Erreur lors de la récupération du réel :", error.message);
  }
};

module.exports = { fetchAndStoreForecast, fetchAndStoreRealData };
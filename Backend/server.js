const express = require('express');
const axios = require('axios');
const { getOrCreateVille, pool } = require('./db');
const { fetchAndStoreForecast, fetchAndStoreRealData } = require('./weatherService');
const app = express();
const port = 3000;

app.use(express.json());

// ROUTE 1 : Recherche et Collecte (Point d'entrée dynamique)
app.get('/search/:nom', async (req, res) => {
  const nomVille = req.params.nom;

  try {
    // 1. Appel au service de géocodage pour trouver les coordonnées réelles
    const geoUrl = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(nomVille)}&count=1&language=fr&format=json`;
    const geoRes = await axios.get(geoUrl);

    // Vérification si la ville existe
    if (!geoRes.data.results || geoRes.data.results.length === 0) {
      return res.status(404).json({ error: "Ville non trouvée" });
    }

    // Extraction des vraies coordonnées
    const { latitude, longitude, name } = geoRes.data.results[0];

    // 2. Récupération ou création de la ville avec ses vraies coordonnées
    // Utilise ta fonction getOrCreateVille ou pool.query directement
    const villeId = await getOrCreateVille(name, latitude, longitude);

    // 3. Collecte des données météo basées sur les VRAIES coordonnées
    await fetchAndStoreForecast(villeId, latitude, longitude); 
    await fetchAndStoreRealData(villeId, latitude, longitude);  

    res.json({ 
      message: "Données mises à jour avec les coordonnées réelles", 
      ville: name, 
      id: villeId,
      coords: { latitude, longitude }
    });

  } catch (err) {
    console.error("Erreur Search:", err.message);
    res.status(500).json({ error: "Erreur serveur lors de la recherche" });
  }
});

// ROUTE 2 : Récupérer la météo stockée (Prévisions)
app.get('/weather/:villeId', async (req, res) => {
  const { villeId } = req.params;
  try {
    const result = await pool.query(
      `SELECT source, temp, date_concernee, type 
       FROM donnees_meteo 
       WHERE ville_id = $1
       AND date_concernee > CURRENT_DATE
       ORDER BY date_concernee ASC, source ASC`,
      [villeId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Erreur lors de la récupération de la météo" });
  }
});

// ROUTE 3 : Récupérer les scores de fiabilité (Calculés par Python)
app.get('/scores/:villeId', async (req, res) => {
  const { villeId } = req.params;
  try {
    const result = await pool.query(
      `SELECT source, score_fiabilite, derniere_maj 
       FROM scores_fiabilite 
       WHERE ville_id = $1 
       ORDER BY score_fiabilite DESC`,
      [villeId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Erreur lors de la récupération des scores" });
  }
});

// ROUTE 4 : Récupérer uniquement le champion de la ville
app.get('/best-source/:villeId', async (req, res) => {
  const { villeId } = req.params;
  try {
    const result = await pool.query(
      `SELECT source, score_fiabilite 
       FROM scores_fiabilite 
       WHERE ville_id = $1 
       ORDER BY score_fiabilite DESC LIMIT 1`,
      [villeId]
    );
    if (result.rows.length === 0) {
        return res.json({ message: "Aucun score calculé pour le moment" });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: "Erreur serveur" });
  }
});

app.listen(port, () => {
  console.log(`Serveur prêt sur http://localhost:${port}`);
});
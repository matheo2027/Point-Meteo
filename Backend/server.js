const express = require('express');
const { getOrCreateVille, pool } = require('./db');
const { fetchAndStoreForecast, fetchAndStoreRealData } = require('./weatherService');
const app = express();
const port = 3000;

app.use(express.json());

// ROUTE 1 : Recherche et Collecte (Point d'entrée)
app.get('/search/:nom', async (req, res) => {
  const nomVille = req.params.nom;
  const lat_test = 48.85; // Paris par défaut
  const lon_test = 2.35;

  try {
    const villeId = await getOrCreateVille(nomVille, lat_test, lon_test);

    // Lance la collecte des prévisions et de la réalité d'hier
    await fetchAndStoreForecast(villeId, lat_test, lon_test); 
    await fetchAndStoreRealData(villeId, lat_test, lon_test);  

    res.json({ 
      message: "Données mises à jour (Futur + Passé)", 
      ville: nomVille, 
      id: villeId 
    });
  } catch (err) {
    res.status(500).json({ error: "Erreur serveur" });
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
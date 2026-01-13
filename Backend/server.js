const express = require('express');
const { getOrCreateVille, pool } = require('./db');
const { fetchAndStoreForecast } = require('./weatherService');
const app = express();
const port = 3000;

app.use(express.json());

app.get('/search/:nom', async (req, res) => {
  const nomVille = req.params.nom;
  
  // Simulation de coordonnées (Paris par défaut pour le test)
  const lat_test = 48.85;
  const lon_test = 2.35;

  try {
    // 1. On récupère ou crée la ville dans la table 'villes'
    const villeId = await getOrCreateVille(nomVille, lat_test, lon_test);

    // 2. On déclenche la récupération des prévisions pour les 5 prochains jours
    // On le fait même si la ville existe déjà pour accumuler nos "preuves" quotidiennes
    await fetchAndStoreForecast(villeId, lat_test, lon_test);

    res.json({ 
      message: "Recherche traitée et prévisions archivées", 
      ville: nomVille, 
      id_en_base: villeId 
    });
  } catch (err) {
    res.status(500).json({ error: "Erreur serveur lors de la recherche" });
  }
});

app.listen(port, () => {
  console.log(`🚀 Serveur prêt sur http://localhost:${port}`);
});
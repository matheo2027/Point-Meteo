const express = require('express');
const { getOrCreateVille, pool } = require('./db');
const { fetchAndStoreForecast, fetchAndStoreRealData } = require('./weatherService');
const app = express();
const port = 3000;

app.use(express.json());

app.get('/search/:nom', async (req, res) => {
  const nomVille = req.params.nom;

  const lat_test = 48.85; // Paris par défaut
  const lon_test = 2.35;

  try {
    const villeId = await getOrCreateVille(nomVille, lat_test, lon_test);

    // On lance les deux en parallèle
    await fetchAndStoreForecast(villeId, lat_test, lon_test); // Prévisions (OM + WAPI)
    await fetchAndStoreRealData(villeId, lat_test, lon_test);  // Réalité (Hier)

    res.json({ message: "Données mises à jour (Futur + Passé)", ville: nomVille, id: villeId });
  } catch (err) {
    res.status(500).json({ error: "Erreur serveur" });
  }
});

app.listen(port, () => {
  console.log(`🚀 Serveur prêt sur http://localhost:${port}`);
});
const express = require('express');
const { getOrCreateVille } = require('./db');
const app = express();
const port = 3000;

app.use(express.json());

// Route de test pour chercher une ville
app.get('/search/:nom', async (req, res) => {
  const nomVille = req.params.nom;
  
  // Pour le test, on simule des coordonnées
  // Plus tard, on utilisera une API de Géocodage ici
  const lat_test = 48.85;
  const lon_test = 2.35;

  try {
    const villeId = await getOrCreateVille(nomVille, lat_test, lon_test);
    res.json({ 
      message: `Ville traitée avec succès`, 
      ville: nomVille, 
      id_en_base: villeId 
    });
  } catch (err) {
    res.status(500).json({ error: "Erreur serveur" });
  }
});

app.listen(port, () => {
  console.log(`🚀 Serveur météo prêt sur http://localhost:${port}`);
});
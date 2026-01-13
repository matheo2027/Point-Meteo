const { Pool } = require('pg');
require('dotenv').config();

// Configuration de la connexion
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

// Fonction magique pour gérer les villes automatiquement
const getOrCreateVille = async (nom, lat, lon) => {
  try {
    // 1. On cherche si la ville existe déjà (nom unique)
    const res = await pool.query('SELECT id FROM villes WHERE nom = $1', [nom]);
    
    if (res.rows.length > 0) {
      console.log(`📍 Ville trouvée en base : ${nom}`);
      return res.rows[0].id;
    } else {
      // 2. Si elle n'existe pas, on l'insère
      const insertRes = await pool.query(
        'INSERT INTO villes (nom, latitude, longitude) VALUES ($1, $2, $3) RETURNING id',
        [nom, lat, lon]
      );
      console.log(`✨ Nouvelle ville enregistrée : ${nom}`);
      return insertRes.rows[0].id;
    }
  } catch (err) {
    console.error('❌ Erreur getOrCreateVille :', err);
    throw err;
  }
};

module.exports = { pool, getOrCreateVille };
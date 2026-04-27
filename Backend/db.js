const { Pool } = require('pg');
require('dotenv').config();

// Configuration de la connexion
const connectionString = process.env.DATABASE_URL || (
  process.env.DB_USER &&
  process.env.DB_PASSWORD &&
  process.env.DB_HOST &&
  process.env.DB_NAME
    ? `postgresql://${process.env.DB_USER}:${process.env.DB_PASSWORD}@${process.env.DB_HOST}:${process.env.DB_PORT || 5432}/${process.env.DB_NAME}`
    : undefined
);

const pool = new Pool({
  connectionString,
  ssl: process.env.DATABASE_URL ? { rejectUnauthorized: false } : false,
});

pool.query('SELECT NOW()', (err) => {
  if (err) {
    console.error('❌ Erreur de connexion à la base de données :', err.stack);
  } else {
    console.log('✅ Connecté à la base de données avec succès !');
  }
});

// Fonction magique pour gérer les villes automatiquement
const getOrCreateVille = async (nom, lat, lon) => {
  try {
    // 1. On cherche si la ville existe déjà (nom unique)
    const res = await pool.query('SELECT id FROM villes WHERE nom = $1', [nom]);
    
    if (res.rows.length > 0) {
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
    console.error('Erreur getOrCreateVille :', err);
    throw err;
  }
};

module.exports = { pool, getOrCreateVille };
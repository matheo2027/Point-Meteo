Pour tester
node server.js
http://localhost:3000/search/Toulouse (ou une autre ville)

Pour vérifier :
psql -U postgres -d meteo_db

SELECT source, temp, date_concernee, type, date_enregistrement 
FROM donnees_meteo 
WHERE ville_id = (SELECT id FROM villes WHERE nom = 'Toulouse')
ORDER BY date_concernee ASC, source ASC;
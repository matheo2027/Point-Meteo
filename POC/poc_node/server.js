const express = require('express');
const { spawn } = require('child_process');
const app = express();
const port = 3000;

app.get('/meteo', (req, res) => {

    console.log("Quelqu'un demande la météo... Lancement de Python !");

    const pythonProcess = spawn('python', ['script.py']);

    pythonProcess.stdout.on('data', (data) => {
        const resultatTexte = data.toString();
        
        const resultatJson = JSON.parse(resultatTexte);

        res.json(resultatJson);
    });

    pythonProcess.stderr.on('data', (data) => {
        console.error(`Erreur Python : ${data}`);
        res.status(500).send('Erreur dans le script Python');
    });
});

app.listen(port, () => {
    console.log(`Le serveur tourne à l'adresse http://localhost:${port}`);
});
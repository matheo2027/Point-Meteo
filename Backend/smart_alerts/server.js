require('dotenv').config();

const express = require('express');
const cors = require('cors');
const cron = require('node-cron');
const axios = require('axios');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// ─── Configuration ────────────────────────────────────────────────────────────

const PORT = process.env.PORT || 3001;
const WEATHER_API = process.env.WEATHER_API_URL || 'https://point-meteo.onrender.com';
const COOLDOWN_MS = (parseInt(process.env.ALERT_COOLDOWN_SECONDS) || 10800) * 1000;
const CRON_SCHEDULE = process.env.CRON_SCHEDULE || '*/30 * * * *';
const DATA_FILE = path.join(__dirname, 'devices.json');
const SA_PATH = process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './firebase-service-account.json';

// ─── Firebase Admin SDK ───────────────────────────────────────────────────────

let firebaseReady = false;

try {
  const serviceAccount = require(path.resolve(SA_PATH));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  firebaseReady = true;
  console.log('✅ Firebase Admin initialisé');
} catch (e) {
  console.warn('⚠️  Firebase Admin non configuré :', e.message);
  console.warn('   → Place firebase-service-account.json et configure .env');
}

// ─── Stockage local (JSON) ────────────────────────────────────────────────────

function loadDevices() {
  if (!fs.existsSync(DATA_FILE)) return {};
  try {
    return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  } catch (_) {
    return {};
  }
}

function saveDevices(devices) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(devices, null, 2));
}

// ─── Express API ──────────────────────────────────────────────────────────────

const app = express();
app.use(cors());
app.use(express.json());

// Sanity check
app.get('/health', (req, res) => res.json({ status: 'ok', firebaseReady }));

// Enregistrer/mettre à jour un appareil et ses règles
app.post('/devices/register', (req, res) => {
  const { fcmToken, rules } = req.body;
  if (!fcmToken || !Array.isArray(rules)) {
    return res.status(400).json({ error: 'fcmToken et rules requis' });
  }

  const devices = loadDevices();
  const existing = Object.values(devices).find(d => d.fcmToken === fcmToken);
  const deviceId = existing?.id || `dev_${Date.now()}`;

  devices[deviceId] = {
    id: deviceId,
    fcmToken,
    rules,
    updatedAt: new Date().toISOString(),
    lastAlerts: existing?.lastAlerts || {},
  };

  saveDevices(devices);
  console.log(`📱 Appareil ${deviceId} enregistré avec ${rules.length} règle(s)`);
  res.json({ deviceId });
});

// Supprimer un appareil
app.delete('/devices/:deviceId', (req, res) => {
  const devices = loadDevices();
  delete devices[req.params.deviceId];
  saveDevices(devices);
  res.json({ success: true });
});

// ─── Logique métier : vérification des conditions météo ──────────────────────

/**
 * Vérifie si une condition météo est remplie pour une règle donnée.
 * Retourne un objet { triggered, message } ou null si pas déclenchée.
 */
async function checkRule(rule, weatherData) {
  const { type, threshold, hoursAhead, cityName } = rule;

  if (!weatherData) return null;

  // Données actuelles (best provider)
  const current = weatherData.best || weatherData[0] || weatherData;
  const temp = current.temp ?? current.temperature ?? null;
  const windSpeed = current.wind_speed ?? current.windspeed ?? current.vent ?? null;

  // WMO codes indiquant pluie/précipitations
  const RAIN_CODES = [51,53,55,56,57,61,63,65,66,67,71,73,75,77,80,81,82,85,86,95,96,99];
  const weatherCode = current.weathercode ?? current.code_meteo ?? 0;
  const hasRain = RAIN_CODES.includes(Number(weatherCode));

  switch (type) {
    case 'rain':
      if (hasRain) {
        return {
          triggered: true,
          title: `🌧️ Pluie à ${cityName}`,
          body: `De la pluie est prévue dans les ${hoursAhead}h — Pense à ton parapluie !`,
        };
      }
      break;

    case 'tempBelow':
      if (temp !== null && temp < threshold) {
        return {
          triggered: true,
          title: `🥶 ${cityName} : température basse`,
          body: `Il fait ${Math.round(temp)}°C — en dessous de ton seuil de ${Math.round(threshold)}°C`,
        };
      }
      break;

    case 'tempAbove':
      if (temp !== null && temp > threshold) {
        return {
          triggered: true,
          title: `🌡️ ${cityName} : températures élevées`,
          body: `Il fait ${Math.round(temp)}°C — au-dessus de ton seuil de ${Math.round(threshold)}°C`,
        };
      }
      break;

    case 'wind':
      if (windSpeed !== null && windSpeed > threshold) {
        return {
          triggered: true,
          title: `💨 ${cityName} : vent fort`,
          body: `Vent à ${Math.round(windSpeed)} km/h — dépasse ton seuil de ${Math.round(threshold)} km/h`,
        };
      }
      break;
  }

  return null;
}

async function getWeatherForCity(cityName) {
  try {
    // Étape 1 : chercher la ville pour obtenir son ID
    const searchRes = await axios.get(
      `${WEATHER_API}/search/${encodeURIComponent(cityName)}`,
      { timeout: 8000 }
    );
    const cityId = searchRes.data?.id;
    if (!cityId) return null;

    // Étape 2 : récupérer la météo
    const weatherRes = await axios.get(`${WEATHER_API}/weather/${cityId}`, {
      timeout: 8000,
    });

    const data = weatherRes.data;
    if (!Array.isArray(data) || data.length === 0) return null;

    // Retourner le meilleur fournisseur (1er) avec le code météo
    return data[0];
  } catch (e) {
    console.warn(`⚠️  Météo indisponible pour "${cityName}": ${e.message}`);
    return null;
  }
}

async function sendFcmNotification(fcmToken, title, body) {
  if (!firebaseReady) {
    console.log(`[DRY-RUN] Notif → ${title} | ${body}`);
    return;
  }

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      android: {
        notification: {
          channelId: 'point_meteo_alerts',
          priority: 'high',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
            badge: 1,
            sound: 'default',
            'content-available': 1,
          },
        },
      },
    });
    console.log(`✉️  Notification envoyée : ${title}`);
  } catch (e) {
    console.error(`❌ Erreur FCM : ${e.message}`);
  }
}

// ─── CRON Job principal ───────────────────────────────────────────────────────

async function runAlertCheck() {
  const devices = loadDevices();
  const deviceList = Object.values(devices);

  if (deviceList.length === 0) {
    console.log('[CRON] Aucun appareil enregistré');
    return;
  }

  console.log(`[CRON] Vérification de ${deviceList.length} appareil(s)...`);
  const now = Date.now();

  // Grouper les règles par ville pour minimiser les appels API
  const cityCache = {};

  for (const device of deviceList) {
    for (const rule of device.rules || []) {
      if (!rule.isEnabled) continue;

      const ruleKey = `${device.id}_${rule.id}`;
      const lastAlertTs = device.lastAlerts?.[ruleKey] ?? 0;

      if (now - lastAlertTs < COOLDOWN_MS) {
        console.log(`[CRON] Cooldown actif pour règle ${ruleKey}`);
        continue;
      }

      const cityKey = rule.cityName.toLowerCase();
      if (!cityCache[cityKey]) {
        cityCache[cityKey] = await getWeatherForCity(rule.cityName);
      }

      const weatherData = cityCache[cityKey];
      const result = await checkRule(rule, weatherData);

      if (result?.triggered) {
        await sendFcmNotification(device.fcmToken, result.title, result.body);
        device.lastAlerts = device.lastAlerts || {};
        device.lastAlerts[ruleKey] = now;
        devices[device.id] = device;
      }
    }
  }

  saveDevices(devices);
  console.log('[CRON] Vérification terminée');
}

// ─── Endpoint de déclenchement manuel (test) ─────────────────────────────────

app.post('/trigger-now', async (req, res) => {
  console.log('[MANUAL] Déclenchement manuel de la vérification des alertes');
  try {
    await runAlertCheck();
    res.json({ success: true, message: 'Vérification effectuée' });
  } catch (e) {
    console.error('[MANUAL] Erreur :', e.message);
    res.status(500).json({ success: false, error: e.message });
  }
});

// ─── Démarrage ────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`🚀 Smart Alerts server lancé sur le port ${PORT}`);
  console.log(`📅 CRON planifié : ${CRON_SCHEDULE}`);
  console.log(`🔔 Cooldown entre alertes : ${COOLDOWN_MS / 1000}s`);
  console.log(`⚡ Déclenchement manuel : POST /trigger-now`);
});

cron.schedule(CRON_SCHEDULE, () => {
  console.log(`\n[CRON] ${new Date().toISOString()} - Lancement vérification alertes`);
  runAlertCheck().catch(console.error);
});

// Vérification immédiate au démarrage (après 5s)
setTimeout(() => runAlertCheck().catch(console.error), 5000);

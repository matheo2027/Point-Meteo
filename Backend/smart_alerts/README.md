# Smart Alerts Backend — Point Météo

Backend CRON job qui vérifie les règles météo des utilisateurs et envoie des notifications push Firebase.

## Architecture

```
Flutter App  ──POST /devices/register──▶  Smart Alerts Server
                                                │
                                    Toutes les 30 min
                                                │
                                                ▼
                                    Vérification météo (point-meteo.onrender.com)
                                                │
                                    Condition remplie ?
                                                │
                                                ▼
                                    Firebase Admin SDK ──▶ Notification push
```

## Installation

```bash
cd backend/smart_alerts
npm install
```

## Configuration

```bash
cp .env.example .env
# Édite .env avec tes vraies valeurs
```

## Firebase Admin SDK

1. Va sur [Firebase Console](https://console.firebase.google.com)
2. Sélectionne ton projet
3. **Paramètres du projet** → **Comptes de service**
4. Clique **Générer une nouvelle clé privée**
5. Sauvegarde le fichier JSON sous `backend/smart_alerts/firebase-service-account.json`

## Démarrage local

```bash
npm run dev    # avec hot-reload
# ou
npm start      # production
```

## Déploiement sur Render

1. Push le dossier `backend/smart_alerts/` sur un repo GitHub
2. Sur Render : **New Web Service** → connecte le repo
3. Configure :
   - **Root Directory**: `backend/smart_alerts`
   - **Build Command**: `npm install`
   - **Start Command**: `npm start`
4. Ajoute les **Environment Variables** depuis ton `.env`
5. Ajoute `firebase-service-account.json` en tant que **Secret File** dans Render
6. Une fois déployé, copie l'URL dans `lib/services/alerts_service.dart` → `defaultBackendUrl`

## Endpoints

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/health` | Sanity check |
| POST | `/devices/register` | Enregistre un appareil + ses règles |
| DELETE | `/devices/:deviceId` | Supprime un appareil |

### POST /devices/register

```json
{
  "fcmToken": "FCM_TOKEN_DE_L_APPAREIL",
  "rules": [
    {
      "id": "1234567890",
      "cityName": "Paris",
      "type": "rain",
      "threshold": 0,
      "hoursAhead": 3,
      "isEnabled": true
    }
  ]
}
```

## Types de règles supportés

| type | Description | threshold |
|------|-------------|-----------|
| `rain` | Pluie dans les X heures | - (utilise `hoursAhead`) |
| `tempBelow` | Température sous X°C | Valeur en °C |
| `tempAbove` | Température au-dessus de X°C | Valeur en °C |
| `wind` | Vent > X km/h | Valeur en km/h |

## Cooldown

Par défaut, une même règle ne peut déclencher une notification qu'une fois toutes les **3 heures** (configurable via `ALERT_COOLDOWN_SECONDS`).

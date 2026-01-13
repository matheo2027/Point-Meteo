# Point-Meteo
Ne jonglez plus entre les applis ! Point Météo compare pour vous les modèles météo mondiaux et sélectionne le plus fiable. Notre algorithme analyse les divergences et l'historique de précision locale pour garantir le meilleur scénario. Fini les mauvaises surprises : profitez d'une synthèse claire et optez toujours pour la prévision la plus sûre.

Guide Rapide : Lancer Flutter sur VS Code
1. Préparer l'émulateur (Côté Android Studio)
Avant de toucher à VS Code, le "téléphone" doit être allumé.

Ouvre Android Studio.

Va dans Virtual Device Manager (via More Actions sur l'écran d'accueil).

Clique sur le bouton Play (triangle vert) de ton appareil (ex: Pixel 5).

Attends que le téléphone affiche l'écran d'accueil Android sur ton bureau.

2. Connecter VS Code à l'émulateur
Si l'appareil n'apparaît pas automatiquement en bas à droite de VS Code :

Fais Ctrl + Shift + P.

Tape Flutter: Select Device.

Sélectionne ton émulateur dans la liste qui apparaît en haut.

Note : Si la commande n'apparaît pas, clique d'abord dans ton fichier lib/main.dart.

3. Lancer l'application
Une fois l'appareil sélectionné :

Option A (Mode Debug) : Appuie sur F5. Cela permet de voir les erreurs en direct dans la "Debug Console".

Option B (Terminal) : Tape flutter run dans le terminal de ton projet test_flutter.
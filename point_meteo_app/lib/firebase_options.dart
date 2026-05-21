// FICHIER GÉNÉRÉ AUTOMATIQUEMENT — À REMPLACER
//
// Étapes :
// 1. Installe FlutterFire CLI : dart pub global activate flutterfire_cli
// 2. Crée un projet Firebase sur https://console.firebase.google.com
// 3. Lance : flutterfire configure
// 4. Ce fichier sera régénéré avec tes vraies clés Firebase
//
// En attendant, une configuration vide est fournie pour que le projet compile.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions ne supporte pas cette plateforme.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB7C4yXdj8e9trSKL034gZlNEft1kYSjIY',
    appId: '1:1061820774452:android:dbc19af095cce248243261',
    messagingSenderId: '1061820774452',
    projectId: 'point-meteo',
    storageBucket: 'point-meteo.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCux-FeNXi-md_YdvaO7LhB36ROHkjf9ps',
    appId: '1:1061820774452:ios:04cbdbe2533e3298243261',
    messagingSenderId: '1061820774452',
    projectId: 'point-meteo',
    storageBucket: 'point-meteo.firebasestorage.app',
    iosBundleId: 'com.example.pointMeteoApp',
  );

  // Web : ajoute une app Web dans Firebase Console puis remplace ces 2 valeurs
  // Firebase Console > Paramètres > Ajouter une application > Web
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REMPLACE-PAR-TA-CLE-WEB',
    appId: 'REMPLACE-PAR-APP-ID-WEB',
    messagingSenderId: '1061820774452',
    projectId: 'point-meteo',
    storageBucket: 'point-meteo.firebasestorage.app',
    authDomain: 'point-meteo.firebaseapp.com',
  );
}
# Super CHK Bros — portage Unity Android

Ce dossier contient la migration Unity 6.3 LTS du jeu Super CHK Bros.

## Contenu déjà porté

- 10 niveaux avec difficulté progressive ;
- personnage 2D, collisions et physique Unity ;
- caméra mobile rapprochée ;
- écran vertical avec 89 % pour le jeu et 11 % pour les commandes ;
- joystick tactile analogique dynamique qui suit le doigt ;
- commandes haut, bas, avant et arrière ;
- saut tactile dynamique avec petit saut et grand saut ;
- pièces, score, vies, progression et record sauvegardé ;
- ennemis, écrasement et boss final à trois points de vie ;
- récupération automatique des images `player.png` et `ennemi*.png` du projet Godot ;
- export APK Android ARMv7 + ARM64 avec IL2CPP ;
- publication automatique de l’APK dans GitHub Actions et dans une GitHub Release.

## Version Unity

Le projet utilise **Unity 6000.3.18f1 (Unity 6.3 LTS)**.

## Ouvrir et compiler localement

1. Installer Unity 6000.3.18f1 avec Android Build Support, Android SDK, NDK et OpenJDK.
2. Ouvrir le dossier `unity` depuis Unity Hub.
3. Dans Unity, lancer `Super CHK Bros > Build Android APK`.
4. L’APK est créé dans `unity/Builds/Android/Super-CHK-Bros-Unity.apk`.

## Compilation GitHub Actions

Le workflow `.github/workflows/build-unity-android.yml` utilise GameCI. Unity impose une activation de licence, même pour une compilation automatique.

Ajouter dans `Settings > Secrets and variables > Actions` :

- `UNITY_LICENSE` : contenu d’un fichier de licence Unity activé ;
- ou `UNITY_EMAIL`, `UNITY_PASSWORD` et `UNITY_SERIAL` pour une licence compatible.

Après activation, lancer le workflow **Build Unity Android APK**. L’APK sera disponible :

- dans l’Artifact `Super-CHK-Bros-Unity-Android` ;
- dans une Release GitHub portant le nom `Super CHK Bros Unity`.

Aucun faux APK n’est généré : le fichier Android provient directement de `BuildPipeline.BuildPlayer` dans Unity.

# SUPER CHK BROS — Godot 4.7.1 Android

Vrai jeu de plateforme 2D Mario-like réalisé avec **Godot 4.7.1**, conçu pour Android en mode paysage.

## Télécharger directement l’APK

Après la réussite de GitHub Actions :

**https://github.com/Chasmet/moi-mario-pygame/releases/latest/download/Super-CHK-Bros.apk**

Le fichier téléchargé est directement `Super-CHK-Bros.apk`, sans faux APK, ZIP ou WebView.

## Gameplay

- 10 niveaux complets et progressifs
- 10 ambiances visuelles différentes
- personnage CHK utilisant `player.png`
- nombreux ennemis utilisant les PNG disponibles dans le dépôt
- commandes tactiles Android : gauche, droite et saut
- accélération, freinage, saut variable, coyote time et saut mémorisé
- plateformes fixes et mobiles
- pièces, vies bonus et points de contrôle
- pièges, trous, lave, eau et zones dangereuses
- ennemis terrestres et volants
- boss aux niveaux 5 et 10
- caméra fluide, tremblements et vibrations
- score, record et progression sauvegardés

## Construction automatique

Le workflow `.github/workflows/build-apk.yml` :

1. utilise Godot 4.7.1 et ses modèles d’export Android ;
2. importe et valide toutes les scènes et tous les scripts ;
3. arrête immédiatement la compilation en cas d’erreur ;
4. exporte un véritable APK Android Godot ;
5. fournit l’APK dans les Artifacts ;
6. publie automatiquement `Super-CHK-Bros.apk` dans la dernière Release après un push sur `main`.

## Contrôles ordinateur

| Action | Touches |
|---|---|
| Gauche | A, Q ou flèche gauche |
| Droite | D ou flèche droite |
| Saut | Espace, W ou flèche haut |

## Structure principale

```text
project.godot
export_presets.cfg
scenes/Main.tscn
scripts/Main.gd
scripts/Player.gd
scripts/Enemy.gd
.github/workflows/build-apk.yml
player.png
ennemis*.png
```

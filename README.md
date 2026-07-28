# SUPER CHK BROS — Godot 4 Android

Vrai jeu de plateforme 2D réalisé avec **Godot 4.3**, conçu pour Android en mode paysage.

## Télécharger directement l’APK

Après la fin de GitHub Actions :

**https://github.com/Chasmet/moi-mario-pygame/releases/latest/download/Super-CHK-Bros.apk**

Le fichier téléchargé est directement `Super-CHK-Bros.apk`, sans ZIP ni TAR.

## Gameplay

- 10 niveaux complets et progressifs
- 10 ambiances visuelles différentes
- personnage CHK utilisant `player.png`
- nombreux ennemis utilisant les PNG disponibles dans le dépôt
- commandes tactiles Android : gauche, droite et saut
- accélération, freinage, saut variable, tolérance de saut et saut mémorisé
- plateformes fixes et mobiles
- pièces, vies bonus et points de contrôle
- pièges, trous, lave, eau et zones dangereuses
- ennemis terrestres et volants
- boss aux niveaux 5 et 10
- caméra fluide, tremblements et vibrations
- score, record et progression sauvegardés

## Construction automatique

Le workflow `.github/workflows/build-apk.yml` :

1. importe le projet avec Godot 4.3 ;
2. valide les scènes et les scripts ;
3. exporte un véritable APK Godot Android ;
4. publie automatiquement `Super-CHK-Bros.apk` dans la dernière Release GitHub.

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

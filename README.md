# SUPER CHK BROS — Godot 4.7 Android

Vrai jeu de plateforme 2D **Mario-like original**, réalisé avec **Godot 4.7 stable** et conçu pour Android en mode paysage.

## Télécharger directement l’APK

Après la réussite de GitHub Actions :

**https://github.com/Chasmet/moi-mario-pygame/releases/latest/download/Super-CHK-Bros.apk**

Le fichier téléchargé est un véritable APK Android directement installable, sans ZIP renommé.

## Gameplay

- 10 niveaux complets et progressifs ;
- 10 ambiances visuelles différentes ;
- personnage CHK utilisant `player.png` ;
- nombreux ennemis utilisant les PNG du dépôt ;
- commandes tactiles Android : gauche, droite et saut ;
- accélération, freinage, saut variable, tolérance de saut et saut mémorisé ;
- plateformes fixes et mobiles ;
- pièces, vies bonus et points de contrôle ;
- pièges, trous, lave, eau et zones dangereuses ;
- ennemis terrestres et volants ;
- boss aux niveaux 5 et 10 ;
- caméra fluide, tremblements et vibrations ;
- score, record et progression sauvegardés.

## Construction automatique avec Godot 4.7

Le workflow `.github/workflows/build-apk.yml` :

1. télécharge Godot 4.7 stable et les modèles d’export Android officiels ;
2. importe toutes les ressources et vérifie les scripts GDScript ;
3. exporte `Super-CHK-Bros.apk` pour ARM32 et ARM64 ;
4. calcule le SHA-256 de l’APK ;
5. publie l’APK dans les Artifacts GitHub Actions et dans la dernière Release.

Le workflow s’arrête réellement en cas d’erreur : aucune commande ne masque un échec de compilation.

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

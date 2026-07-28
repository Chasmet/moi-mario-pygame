using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build;
using UnityEngine;

namespace SuperChkBrosEditor
{
    public static class ArtImporter
    {
        private const string DestinationAssetPath = "Assets/Resources/ImportedArt";

        public static void PrepareImportedArt()
        {
            string unityRoot = Directory.GetParent(Application.dataPath)?.FullName ?? string.Empty;
            string repositoryRoot = Directory.GetParent(unityRoot)?.FullName ?? string.Empty;
            string destination = Path.Combine(Application.dataPath, "Resources", "ImportedArt");
            Directory.CreateDirectory(destination);

            string playerSource = Path.Combine(repositoryRoot, "player.png");
            if (File.Exists(playerSource))
            {
                File.Copy(playerSource, Path.Combine(destination, "player.png"), true);
            }

            List<string> enemies = Directory.Exists(repositoryRoot)
                ? Directory.GetFiles(repositoryRoot, "*.png", SearchOption.TopDirectoryOnly)
                    .Where(path => Path.GetFileName(path).StartsWith("ennemi", StringComparison.OrdinalIgnoreCase))
                    .OrderBy(path => path, StringComparer.OrdinalIgnoreCase)
                    .ToList()
                : new List<string>();

            for (int index = 0; index < enemies.Count; index++)
            {
                File.Copy(enemies[index], Path.Combine(destination, $"enemy{index + 1:00}.png"), true);
            }

            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
            if (!AssetDatabase.IsValidFolder(DestinationAssetPath))
            {
                throw new BuildFailedException("Unity art import folder was not created.");
            }

            foreach (string guid in AssetDatabase.FindAssets("t:Texture2D", new[] { DestinationAssetPath }))
            {
                string assetPath = AssetDatabase.GUIDToAssetPath(guid);
                TextureImporter importer = AssetImporter.GetAtPath(assetPath) as TextureImporter;
                if (importer == null)
                {
                    continue;
                }

                importer.textureType = TextureImporterType.Sprite;
                importer.spriteImportMode = SpriteImportMode.Single;
                importer.spritePixelsPerUnit = 100f;
                importer.alphaIsTransparency = true;
                importer.mipmapEnabled = false;
                importer.filterMode = FilterMode.Bilinear;
                importer.SaveAndReimport();
            }
        }
    }
}

using System;
using System.IO;
using SuperChkBros;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace SuperChkBrosEditor
{
    public static class BuildAndroid
    {
        private const string ScenePath = "Assets/Scenes/Main.unity";

        [MenuItem("Super CHK Bros/Build Android APK")]
        public static void PerformBuild()
        {
            ArtImporter.PrepareImportedArt();
            Directory.CreateDirectory(Path.Combine(Application.dataPath, "Scenes"));
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            new GameObject("Super CHK Bros Unity").AddComponent<SuperChkGame>();
            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };

            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
            EditorUserBuildSettings.buildAppBundle = false;
            PlayerSettings.companyName = "CHK Games";
            PlayerSettings.productName = "Super CHK Bros Unity";
            PlayerSettings.bundleVersion = "1.0.0-unity";
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.chknoir.superchkbros.unity");
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.bundleVersionCode = 100;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel23;
            PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevelAuto;
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARMv7 | AndroidArchitecture.ARM64;

            string outputPath = Environment.GetEnvironmentVariable("UNITY_BUILD_PATH");
            if (string.IsNullOrWhiteSpace(outputPath))
            {
                outputPath = Path.Combine("Builds", "Android", "Super-CHK-Bros-Unity.apk");
            }
            Directory.CreateDirectory(Path.GetDirectoryName(outputPath) ?? "Builds/Android");

            BuildPlayerOptions options = new BuildPlayerOptions
            {
                scenes = new[] { ScenePath },
                locationPathName = outputPath,
                target = BuildTarget.Android,
                targetGroup = BuildTargetGroup.Android,
                options = BuildOptions.CleanBuildCache
            };
            BuildReport report = BuildPipeline.BuildPlayer(options);
            if (report.summary.result != BuildResult.Succeeded)
            {
                throw new BuildFailedException("Unity Android build failed: " + report.summary.result);
            }
        }
    }
}

using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace SuperChkBros
{
    public sealed class SuperChkGame : MonoBehaviour
    {
        public static SuperChkGame Instance { get; private set; }

        private static readonly string[] LevelNames =
        {
            "Côte ensoleillée", "Jungle des lianes", "Dunes rouges", "Montagne glacée",
            "Grotte du gardien", "Usine mécanique", "Ville nocturne", "Volcan interdit",
            "Royaume des nuages", "Forteresse finale"
        };

        private static readonly Color[] SkyColors =
        {
            new Color32(85,189,232,255), new Color32(85,168,108,255), new Color32(232,168,91,255),
            new Color32(126,174,228,255), new Color32(36,42,70,255), new Color32(111,127,141,255),
            new Color32(23,29,79,255), new Color32(92,29,25,255), new Color32(101,189,232,255),
            new Color32(27,16,40,255)
        };

        private static readonly Color[] GroundColors =
        {
            new Color32(79,190,80,255), new Color32(39,141,67,255), new Color32(216,154,67,255),
            new Color32(214,246,255,255), new Color32(127,119,138,255), new Color32(211,166,43,255),
            new Color32(49,212,197,255), new Color32(142,55,37,255), new Color32(241,245,247,255),
            new Color32(177,63,77,255)
        };

        private Transform worldRoot;
        private Camera gameCamera;
        private PlayerController player;
        private CameraFollow cameraFollow;
        private Canvas canvas;
        private Text scoreText;
        private Text livesText;
        private Text coinText;
        private Text levelText;
        private Text highText;
        private Text messageText;
        private Slider progressSlider;
        private Sprite whiteSprite;
        private Sprite playerSprite;
        private readonly List<Sprite> enemySprites = new List<Sprite>();

        private int currentLevel = 1;
        private int score;
        private int lives = 5;
        private int coins;
        private int unlockedLevel = 1;
        private int highScore;
        private float levelWidth = 40f;
        private Vector2 spawnPoint;
        private bool transitioning;

        public float LevelWidth => levelWidth;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }

            Instance = this;
            Application.targetFrameRate = 60;
            Screen.orientation = ScreenOrientation.Portrait;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            Physics2D.gravity = new Vector2(0f, -28f);

            highScore = PlayerPrefs.GetInt("high_score", 0);
            unlockedLevel = Mathf.Clamp(PlayerPrefs.GetInt("unlocked_level", 1), 1, 10);

            CreateSharedSprites();
            CreateCamera();
            CreateEventSystem();
            CreateWorld();
            CreatePlayer();
            CreateInterface();
            LoadLevel(1);
        }

        private void Update()
        {
            if (player != null && progressSlider != null)
            {
                progressSlider.value = Mathf.Clamp01(player.transform.position.x / Mathf.Max(levelWidth, 1f));
            }
        }

        private void CreateSharedSprites()
        {
            Texture2D texture = new Texture2D(1, 1, TextureFormat.RGBA32, false);
            texture.name = "RuntimeWhiteTexture";
            texture.SetPixel(0, 0, Color.white);
            texture.Apply();
            whiteSprite = Sprite.Create(texture, new Rect(0, 0, 1, 1), new Vector2(0.5f, 0.5f), 1f);

            playerSprite = Resources.Load<Sprite>("ImportedArt/player");
            for (int index = 1; index <= 16; index++)
            {
                Sprite sprite = Resources.Load<Sprite>($"ImportedArt/enemy{index:00}");
                if (sprite != null)
                {
                    enemySprites.Add(sprite);
                }
            }
        }

        private void CreateCamera()
        {
            GameObject cameraObject = new GameObject("Main Camera");
            gameCamera = cameraObject.AddComponent<Camera>();
            gameCamera.orthographic = true;
            gameCamera.orthographicSize = 5.4f;
            gameCamera.clearFlags = CameraClearFlags.SolidColor;
            gameCamera.rect = new Rect(0f, 0.11f, 1f, 0.89f);
            gameCamera.transform.position = new Vector3(2f, 0.2f, -10f);
            cameraObject.tag = "MainCamera";
            cameraFollow = cameraObject.AddComponent<CameraFollow>();
        }

        private static void CreateEventSystem()
        {
            if (FindFirstObjectByType<EventSystem>() != null)
            {
                return;
            }

            GameObject eventSystem = new GameObject("EventSystem");
            eventSystem.AddComponent<EventSystem>();
            eventSystem.AddComponent<StandaloneInputModule>();
        }

        private void CreateWorld()
        {
            GameObject world = new GameObject("World");
            worldRoot = world.transform;
        }

        private void CreatePlayer()
        {
            GameObject playerObject = new GameObject("Player");
            playerObject.transform.SetParent(worldRoot);

            SpriteRenderer renderer = playerObject.AddComponent<SpriteRenderer>();
            renderer.sprite = playerSprite != null ? playerSprite : whiteSprite;
            renderer.sortingOrder = 20;
            renderer.color = playerSprite != null ? Color.white : new Color32(34, 161, 232, 255);
            FitRenderer(renderer, new Vector2(1.15f, 1.55f));

            Rigidbody2D body = playerObject.AddComponent<Rigidbody2D>();
            body.gravityScale = 1f;
            body.freezeRotation = true;
            body.collisionDetectionMode = CollisionDetectionMode2D.Continuous;
            body.interpolation = RigidbodyInterpolation2D.Interpolate;

            BoxCollider2D collider = playerObject.AddComponent<BoxCollider2D>();
            collider.size = new Vector2(0.62f, 1.18f);
            collider.offset = new Vector2(0f, -0.04f);

            player = playerObject.AddComponent<PlayerController>();
            player.Configure(renderer, body, collider);
            cameraFollow.SetTarget(playerObject.transform);
        }

        private void CreateInterface()
        {
            GameObject canvasObject = new GameObject("Mobile UI");
            canvas = canvasObject.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 100;
            CanvasScaler scaler = canvasObject.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(720f, 1280f);
            scaler.matchWidthOrHeight = 0.5f;
            canvasObject.AddComponent<GraphicRaycaster>();

            CreateHud(canvasObject.transform);
            CreateControls(canvasObject.transform);
        }

        private void CreateHud(Transform parent)
        {
            scoreText = CreateText(parent, "Score", new Vector2(0.02f, 0.94f), new Vector2(0.38f, 0.99f), TextAnchor.UpperLeft, 24);
            livesText = CreateText(parent, "Vies", new Vector2(0.02f, 0.90f), new Vector2(0.38f, 0.95f), TextAnchor.UpperLeft, 22);
            coinText = CreateText(parent, "Pièces", new Vector2(0.02f, 0.86f), new Vector2(0.38f, 0.91f), TextAnchor.UpperLeft, 22);
            levelText = CreateText(parent, "Niveau", new Vector2(0.62f, 0.94f), new Vector2(0.98f, 0.99f), TextAnchor.UpperRight, 24);
            highText = CreateText(parent, "Record", new Vector2(0.62f, 0.90f), new Vector2(0.98f, 0.95f), TextAnchor.UpperRight, 20);
            messageText = CreateText(parent, string.Empty, new Vector2(0.12f, 0.55f), new Vector2(0.88f, 0.72f), TextAnchor.MiddleCenter, 36);
            messageText.fontStyle = FontStyle.Bold;
            messageText.color = Color.white;

            GameObject sliderObject = new GameObject("Progress");
            sliderObject.transform.SetParent(parent, false);
            RectTransform sliderRect = sliderObject.AddComponent<RectTransform>();
            sliderRect.anchorMin = new Vector2(0.34f, 0.965f);
            sliderRect.anchorMax = new Vector2(0.66f, 0.98f);
            sliderRect.offsetMin = Vector2.zero;
            sliderRect.offsetMax = Vector2.zero;
            progressSlider = sliderObject.AddComponent<Slider>();
            progressSlider.minValue = 0f;
            progressSlider.maxValue = 1f;
            progressSlider.interactable = false;

            Image background = sliderObject.AddComponent<Image>();
            background.color = new Color(0f, 0f, 0f, 0.45f);
            progressSlider.targetGraphic = background;

            GameObject fillObject = new GameObject("Fill");
            fillObject.transform.SetParent(sliderObject.transform, false);
            RectTransform fillRect = fillObject.AddComponent<RectTransform>();
            fillRect.anchorMin = Vector2.zero;
            fillRect.anchorMax = Vector2.one;
            fillRect.offsetMin = new Vector2(2f, 2f);
            fillRect.offsetMax = new Vector2(-2f, -2f);
            Image fillImage = fillObject.AddComponent<Image>();
            fillImage.color = new Color32(55, 193, 255, 255);
            progressSlider.fillRect = fillRect;
        }

        private void CreateControls(Transform parent)
        {
            GameObject panelObject = CreatePanel(parent, "ControlsPanel", new Vector2(0f, 0f), new Vector2(1f, 0.11f), new Color32(8, 13, 24, 255));
            RectTransform panelRect = panelObject.GetComponent<RectTransform>();

            GameObject separator = CreatePanel(panelObject.transform, "Separator", new Vector2(0f, 0.975f), new Vector2(1f, 1f), new Color32(51, 184, 255, 255));
            separator.GetComponent<Image>().raycastTarget = false;

            GameObject joystickZone = CreatePanel(panelObject.transform, "JoystickZone", new Vector2(0f, 0f), new Vector2(0.56f, 1f), new Color(0f, 0f, 0f, 0.001f));
            VirtualJoystick joystick = joystickZone.AddComponent<VirtualJoystick>();
            joystick.Configure(player, 56f, 0.055f);

            GameObject jumpZone = CreatePanel(panelObject.transform, "JumpZone", new Vector2(0.56f, 0f), new Vector2(0.91f, 1f), new Color(0f, 0f, 0f, 0.001f));
            DynamicJumpZone jump = jumpZone.AddComponent<DynamicJumpZone>();
            jump.Configure(player, 58f);

            GameObject pauseObject = CreatePanel(panelObject.transform, "Pause", new Vector2(0.91f, 0.12f), new Vector2(0.99f, 0.88f), new Color32(48, 56, 68, 230));
            Button pauseButton = pauseObject.AddComponent<Button>();
            pauseButton.targetGraphic = pauseObject.GetComponent<Image>();
            pauseButton.onClick.AddListener(TogglePause);
            Text pauseLabel = CreateText(pauseObject.transform, "Ⅱ", Vector2.zero, Vector2.one, TextAnchor.MiddleCenter, 22);
            pauseLabel.raycastTarget = false;

            _ = panelRect;
        }

        private void LoadLevel(int level)
        {
            if (transitioning)
            {
                return;
            }

            transitioning = true;
            Time.timeScale = 1f;
            currentLevel = Mathf.Clamp(level, 1, 10);
            coins = 0;
            ClearLevel();
            BuildLevel(currentLevel);
            RespawnPlayer(false);
            UpdateHud();
            StartCoroutine(ShowMessage($"NIVEAU {currentLevel}\n{LevelNames[currentLevel - 1]}", 1.35f));
            transitioning = false;
        }

        private void ClearLevel()
        {
            List<GameObject> children = new List<GameObject>();
            foreach (Transform child in worldRoot)
            {
                if (player == null || child.gameObject != player.gameObject)
                {
                    children.Add(child.gameObject);
                }
            }

            foreach (GameObject child in children)
            {
                Destroy(child);
            }
        }

        private void BuildLevel(int level)
        {
            Color sky = SkyColors[level - 1];
            Color ground = GroundColors[level - 1];
            gameCamera.backgroundColor = sky;
            levelWidth = 34f + level * 3.6f;
            spawnPoint = new Vector2(1.5f, -2.35f);

            System.Random random = new System.Random(7341 + level * 981);
            float groundY = -3.35f;
            float cursor = 0f;
            int segmentIndex = 0;
            while (cursor < levelWidth)
            {
                float segmentWidth = Mathf.Min(7.5f + (float)random.NextDouble() * 4f, levelWidth - cursor);
                bool createGap = segmentIndex > 0 && cursor < levelWidth - 8f && random.NextDouble() < 0.22 + level * 0.012;
                if (!createGap)
                {
                    CreatePlatform(new Vector2(cursor + segmentWidth * 0.5f, groundY), new Vector2(segmentWidth, 1.15f), ground, "Ground");
                }
                else
                {
                    float safeWidth = Mathf.Max(2.6f, segmentWidth * 0.42f);
                    CreatePlatform(new Vector2(cursor + safeWidth * 0.5f, groundY), new Vector2(safeWidth, 1.15f), ground, "Ground");
                }

                cursor += segmentWidth;
                segmentIndex++;
            }

            CreatePlatform(new Vector2(levelWidth - 3f, groundY), new Vector2(7f, 1.15f), ground, "GoalGround");

            float x = 4f;
            int platformNumber = 0;
            while (x < levelWidth - 5f)
            {
                float width = 2.4f + (float)random.NextDouble() * 2.4f;
                float y = -1.45f + (float)random.NextDouble() * 3.6f;
                if (platformNumber % 5 == 0)
                {
                    y = 0.6f + (float)random.NextDouble() * 1.7f;
                }

                CreatePlatform(new Vector2(x, y), new Vector2(width, 0.38f), ground * 0.9f + Color.white * 0.1f, "Platform");
                CreateCoinLine(x - width * 0.35f, x + width * 0.35f, y + 0.65f, 2 + random.Next(0, 3));

                if (platformNumber % 3 == 1)
                {
                    CreateEnemy(new Vector2(x, y + 0.65f), width * 0.65f, false, level);
                }

                x += 4.2f + (float)random.NextDouble() * 3.2f;
                platformNumber++;
            }

            for (int enemy = 0; enemy < 2 + level / 2; enemy++)
            {
                float enemyX = 7f + (float)random.NextDouble() * Mathf.Max(4f, levelWidth - 15f);
                CreateEnemy(new Vector2(enemyX, -2.15f), 2.3f, false, level);
            }

            if (level == 10)
            {
                CreateEnemy(new Vector2(levelWidth - 8.5f, -1.9f), 4f, true, level);
            }

            CreateGoal(new Vector2(levelWidth - 1.6f, -1.65f));
        }

        private void CreatePlatform(Vector2 position, Vector2 size, Color color, string objectName)
        {
            GameObject platform = new GameObject(objectName);
            platform.transform.SetParent(worldRoot);
            platform.transform.position = position;
            SpriteRenderer renderer = platform.AddComponent<SpriteRenderer>();
            renderer.sprite = whiteSprite;
            renderer.color = color;
            renderer.sortingOrder = 2;
            platform.transform.localScale = new Vector3(size.x, size.y, 1f);
            BoxCollider2D collider = platform.AddComponent<BoxCollider2D>();
            collider.size = Vector2.one;
        }

        private void CreateCoinLine(float startX, float endX, float y, int count)
        {
            for (int index = 0; index < count; index++)
            {
                float t = count <= 1 ? 0.5f : index / (float)(count - 1);
                CreateCoin(new Vector2(Mathf.Lerp(startX, endX, t), y));
            }
        }

        private void CreateCoin(Vector2 position)
        {
            GameObject coin = new GameObject("Coin");
            coin.transform.SetParent(worldRoot);
            coin.transform.position = position;
            coin.transform.localScale = Vector3.one * 0.34f;
            SpriteRenderer renderer = coin.AddComponent<SpriteRenderer>();
            renderer.sprite = whiteSprite;
            renderer.color = new Color32(255, 221, 55, 255);
            renderer.sortingOrder = 8;
            CircleCollider2D collider = coin.AddComponent<CircleCollider2D>();
            collider.isTrigger = true;
            coin.AddComponent<CoinPickup>();
        }

        private void CreateEnemy(Vector2 position, float patrolDistance, bool boss, int level)
        {
            GameObject enemy = new GameObject(boss ? "Boss" : "Enemy");
            enemy.transform.SetParent(worldRoot);
            enemy.transform.position = position;

            SpriteRenderer renderer = enemy.AddComponent<SpriteRenderer>();
            Sprite art = enemySprites.Count > 0 ? enemySprites[(level + Mathf.RoundToInt(position.x)) % enemySprites.Count] : null;
            renderer.sprite = art != null ? art : whiteSprite;
            renderer.color = art != null ? Color.white : (boss ? new Color32(171, 36, 50, 255) : new Color32(234, 94, 55, 255));
            renderer.sortingOrder = 12;
            FitRenderer(renderer, boss ? new Vector2(1.8f, 2.25f) : new Vector2(0.95f, 1.1f));

            Rigidbody2D body = enemy.AddComponent<Rigidbody2D>();
            body.bodyType = RigidbodyType2D.Kinematic;
            body.freezeRotation = true;
            BoxCollider2D collider = enemy.AddComponent<BoxCollider2D>();
            collider.size = boss ? new Vector2(1.25f, 1.7f) : new Vector2(0.72f, 0.82f);

            EnemyController controller = enemy.AddComponent<EnemyController>();
            controller.Configure(position.x - patrolDistance * 0.5f, position.x + patrolDistance * 0.5f, boss ? 3 : 1, boss ? 1.8f : 1.3f);
        }

        private void CreateGoal(Vector2 position)
        {
            GameObject goal = new GameObject("Goal");
            goal.transform.SetParent(worldRoot);
            goal.transform.position = position;

            SpriteRenderer pole = goal.AddComponent<SpriteRenderer>();
            pole.sprite = whiteSprite;
            pole.color = new Color32(245, 245, 245, 255);
            pole.sortingOrder = 5;
            goal.transform.localScale = new Vector3(0.16f, 3.4f, 1f);

            BoxCollider2D trigger = goal.AddComponent<BoxCollider2D>();
            trigger.isTrigger = true;
            trigger.size = new Vector2(6f, 1f);
            goal.AddComponent<GoalTrigger>();

            GameObject flag = new GameObject("Flag");
            flag.transform.SetParent(goal.transform, false);
            flag.transform.localPosition = new Vector3(2.5f, 0.34f, 0f);
            flag.transform.localScale = new Vector3(5f, 0.22f, 1f);
            SpriteRenderer flagRenderer = flag.AddComponent<SpriteRenderer>();
            flagRenderer.sprite = whiteSprite;
            flagRenderer.color = new Color32(43, 174, 255, 255);
            flagRenderer.sortingOrder = 6;
        }

        public void CollectCoin(GameObject coinObject)
        {
            coins++;
            score += 100;
            Destroy(coinObject);
            UpdateHud();
        }

        public void AddEnemyScore(bool boss)
        {
            score += boss ? 3000 : 400;
            UpdateHud();
        }

        public void PlayerDamaged()
        {
            if (transitioning || player == null || player.IsInvincible)
            {
                return;
            }

            lives--;
            UpdateHud();
            if (lives <= 0)
            {
                lives = 5;
                score = 0;
                StartCoroutine(RestartAfterDelay());
            }
            else
            {
                RespawnPlayer(true);
            }
        }

        private IEnumerator RestartAfterDelay()
        {
            transitioning = true;
            yield return ShowMessage("GAME OVER", 1.2f);
            transitioning = false;
            LoadLevel(1);
        }

        private void RespawnPlayer(bool invincible)
        {
            player.transform.position = spawnPoint;
            player.ResetMotion();
            if (invincible)
            {
                player.SetInvincible(1.4f);
            }
        }

        public void ReachGoal()
        {
            if (transitioning)
            {
                return;
            }

            if (FindFirstObjectByType<EnemyController>(FindObjectsInactive.Exclude) is EnemyController enemy && enemy.IsBoss)
            {
                StartCoroutine(ShowMessage("BOSS À VAINCRE", 0.8f));
                return;
            }

            StartCoroutine(CompleteLevel());
        }

        private IEnumerator CompleteLevel()
        {
            transitioning = true;
            score += 1500 + currentLevel * 250;
            unlockedLevel = Mathf.Max(unlockedLevel, Mathf.Min(10, currentLevel + 1));
            SaveProgress();
            yield return ShowMessage(currentLevel == 10 ? "JEU TERMINÉ !" : "NIVEAU TERMINÉ", 1.4f);
            int next = currentLevel == 10 ? 1 : currentLevel + 1;
            transitioning = false;
            LoadLevel(next);
        }

        private void SaveProgress()
        {
            highScore = Mathf.Max(highScore, score);
            PlayerPrefs.SetInt("high_score", highScore);
            PlayerPrefs.SetInt("unlocked_level", unlockedLevel);
            PlayerPrefs.Save();
        }

        private void TogglePause()
        {
            Time.timeScale = Time.timeScale > 0.5f ? 0f : 1f;
            messageText.text = Time.timeScale < 0.5f ? "PAUSE" : string.Empty;
        }

        private IEnumerator ShowMessage(string text, float duration)
        {
            messageText.text = text;
            float elapsed = 0f;
            while (elapsed < duration)
            {
                elapsed += Time.unscaledDeltaTime;
                yield return null;
            }
            messageText.text = string.Empty;
        }

        private void UpdateHud()
        {
            highScore = Mathf.Max(highScore, score);
            scoreText.text = $"SCORE {score:000000}";
            livesText.text = $"VIES × {lives}";
            coinText.text = $"PIÈCES × {coins}";
            levelText.text = $"NIVEAU {currentLevel}/10";
            highText.text = $"RECORD {highScore:000000}";
        }

        private static GameObject CreatePanel(Transform parent, string objectName, Vector2 anchorMin, Vector2 anchorMax, Color color)
        {
            GameObject panel = new GameObject(objectName);
            panel.transform.SetParent(parent, false);
            RectTransform rect = panel.AddComponent<RectTransform>();
            rect.anchorMin = anchorMin;
            rect.anchorMax = anchorMax;
            rect.offsetMin = Vector2.zero;
            rect.offsetMax = Vector2.zero;
            Image image = panel.AddComponent<Image>();
            image.color = color;
            return panel;
        }

        private static Text CreateText(Transform parent, string value, Vector2 anchorMin, Vector2 anchorMax, TextAnchor alignment, int fontSize)
        {
            GameObject textObject = new GameObject("Text");
            textObject.transform.SetParent(parent, false);
            RectTransform rect = textObject.AddComponent<RectTransform>();
            rect.anchorMin = anchorMin;
            rect.anchorMax = anchorMax;
            rect.offsetMin = Vector2.zero;
            rect.offsetMax = Vector2.zero;
            Text text = textObject.AddComponent<Text>();
            text.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            text.text = value;
            text.alignment = alignment;
            text.fontSize = fontSize;
            text.color = Color.white;
            text.horizontalOverflow = HorizontalWrapMode.Overflow;
            text.verticalOverflow = VerticalWrapMode.Overflow;
            text.resizeTextForBestFit = false;
            return text;
        }

        private static void FitRenderer(SpriteRenderer renderer, Vector2 targetSize)
        {
            if (renderer.sprite == null)
            {
                renderer.transform.localScale = new Vector3(targetSize.x, targetSize.y, 1f);
                return;
            }

            Vector2 spriteSize = renderer.sprite.bounds.size;
            if (spriteSize.x <= 0f || spriteSize.y <= 0f)
            {
                return;
            }

            float factor = Mathf.Min(targetSize.x / spriteSize.x, targetSize.y / spriteSize.y);
            renderer.transform.localScale = Vector3.one * factor;
        }
    }

    public sealed class CoinPickup : MonoBehaviour
    {
        private void OnTriggerEnter2D(Collider2D other)
        {
            if (other.GetComponent<PlayerController>() != null)
            {
                SuperChkGame.Instance.CollectCoin(gameObject);
            }
        }
    }

    public sealed class GoalTrigger : MonoBehaviour
    {
        private void OnTriggerEnter2D(Collider2D other)
        {
            if (other.GetComponent<PlayerController>() != null)
            {
                SuperChkGame.Instance.ReachGoal();
            }
        }
    }
}

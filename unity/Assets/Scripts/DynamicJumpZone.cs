using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace SuperChkBros
{
    public sealed class DynamicJumpZone : MonoBehaviour, IPointerDownHandler, IPointerUpHandler, IDragHandler
    {
        private PlayerController player;
        private RectTransform zoneRect;
        private RectTransform visualRect;
        private Image visualImage;
        private Text label;
        private float radius = 58f;
        private int activePointer = int.MinValue;

        public void Configure(PlayerController target, float controlRadius)
        {
            player = target;
            radius = Mathf.Max(40f, controlRadius);
            zoneRect = GetComponent<RectTransform>();
            CreateVisual();
        }

        private void Awake()
        {
            zoneRect = GetComponent<RectTransform>();
        }

        private void CreateVisual()
        {
            if (visualRect != null)
            {
                return;
            }

            GameObject visual = new GameObject("DynamicJumpButton");
            visual.transform.SetParent(transform, false);
            visualRect = visual.AddComponent<RectTransform>();
            visualRect.sizeDelta = Vector2.one * radius * 2f;
            visualImage = visual.AddComponent<Image>();
            visualImage.sprite = CreateCircleSprite(128);
            visualImage.color = new Color(0.55f, 0.27f, 0.06f, 0.62f);
            visualImage.raycastTarget = false;

            GameObject textObject = new GameObject("Label");
            textObject.transform.SetParent(visual.transform, false);
            RectTransform textRect = textObject.AddComponent<RectTransform>();
            textRect.anchorMin = Vector2.zero;
            textRect.anchorMax = Vector2.one;
            textRect.offsetMin = Vector2.zero;
            textRect.offsetMax = Vector2.zero;
            label = textObject.AddComponent<Text>();
            label.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            label.text = "SAUT";
            label.alignment = TextAnchor.MiddleCenter;
            label.fontSize = 22;
            label.fontStyle = FontStyle.Bold;
            label.color = Color.white;
            label.raycastTarget = false;

            SetRestingPosition();
        }

        private void Start()
        {
            SetRestingPosition();
        }

        public void OnPointerDown(PointerEventData eventData)
        {
            if (activePointer != int.MinValue)
            {
                return;
            }

            activePointer = eventData.pointerId;
            MoveVisual(ScreenToLocal(eventData));
            visualImage.color = new Color(1f, 0.55f, 0.10f, 1f);
            visualRect.localScale = Vector3.one * 1.06f;
            player?.PressJump();
        }

        public void OnDrag(PointerEventData eventData)
        {
            if (eventData.pointerId == activePointer)
            {
                MoveVisual(ScreenToLocal(eventData));
            }
        }

        public void OnPointerUp(PointerEventData eventData)
        {
            if (eventData.pointerId != activePointer)
            {
                return;
            }

            activePointer = int.MinValue;
            player?.ReleaseJump();
            SetRestingPosition();
        }

        private Vector2 ScreenToLocal(PointerEventData eventData)
        {
            RectTransformUtility.ScreenPointToLocalPointInRectangle(
                zoneRect,
                eventData.position,
                eventData.pressEventCamera,
                out Vector2 local);
            return local;
        }

        private void MoveVisual(Vector2 local)
        {
            Rect rect = zoneRect.rect;
            float padding = radius + 4f;
            visualRect.anchoredPosition = new Vector2(
                Mathf.Clamp(local.x, rect.xMin + padding, rect.xMax - padding),
                Mathf.Clamp(local.y, rect.yMin + padding, rect.yMax - padding));
        }

        private void SetRestingPosition()
        {
            if (zoneRect == null || visualRect == null)
            {
                return;
            }

            Rect rect = zoneRect.rect;
            visualRect.anchoredPosition = new Vector2(rect.center.x, rect.center.y);
            visualRect.localScale = Vector3.one;
            visualImage.color = new Color(0.55f, 0.27f, 0.06f, 0.68f);
        }

        private static Sprite CreateCircleSprite(int size)
        {
            Texture2D texture = new Texture2D(size, size, TextureFormat.RGBA32, false);
            texture.name = "RuntimeJumpCircle";
            Vector2 center = Vector2.one * (size - 1) * 0.5f;
            float radius = size * 0.5f - 1f;
            for (int y = 0; y < size; y++)
            {
                for (int x = 0; x < size; x++)
                {
                    float distance = Vector2.Distance(new Vector2(x, y), center);
                    float alpha = Mathf.Clamp01(radius - distance + 1f);
                    texture.SetPixel(x, y, new Color(1f, 1f, 1f, alpha));
                }
            }
            texture.Apply();
            return Sprite.Create(texture, new Rect(0, 0, size, size), Vector2.one * 0.5f, 100f);
        }
    }
}

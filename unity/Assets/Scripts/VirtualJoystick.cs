using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace SuperChkBros
{
    public sealed class VirtualJoystick : MonoBehaviour, IPointerDownHandler, IPointerUpHandler, IDragHandler
    {
        private PlayerController player;
        private RectTransform zoneRect;
        private RectTransform baseRect;
        private RectTransform knobRect;
        private Image baseImage;
        private Image knobImage;
        private float radius = 56f;
        private float deadzone = 0.055f;
        private int activePointer = int.MinValue;
        private Vector2 dynamicCenter;

        public void Configure(PlayerController target, float controlRadius, float controlDeadzone)
        {
            player = target;
            radius = Mathf.Max(36f, controlRadius);
            deadzone = Mathf.Clamp(controlDeadzone, 0.01f, 0.25f);
            zoneRect = GetComponent<RectTransform>();
            CreateVisuals();
        }

        private void Awake()
        {
            zoneRect = GetComponent<RectTransform>();
        }

        private void CreateVisuals()
        {
            if (baseRect != null)
            {
                return;
            }

            GameObject baseObject = new GameObject("JoystickBase");
            baseObject.transform.SetParent(transform, false);
            baseRect = baseObject.AddComponent<RectTransform>();
            baseRect.sizeDelta = Vector2.one * radius * 2f;
            baseImage = baseObject.AddComponent<Image>();
            baseImage.sprite = CreateCircleSprite(128);
            baseImage.color = new Color(0.07f, 0.22f, 0.38f, 0.50f);
            baseImage.raycastTarget = false;

            GameObject knobObject = new GameObject("JoystickKnob");
            knobObject.transform.SetParent(transform, false);
            knobRect = knobObject.AddComponent<RectTransform>();
            knobRect.sizeDelta = Vector2.one * radius * 0.92f;
            knobImage = knobObject.AddComponent<Image>();
            knobImage.sprite = CreateCircleSprite(96);
            knobImage.color = new Color(0.18f, 0.62f, 0.95f, 0.78f);
            knobImage.raycastTarget = false;

            SetRestingPosition();
        }

        private void Start()
        {
            SetRestingPosition();
        }

        private void SetRestingPosition()
        {
            if (zoneRect == null || baseRect == null || knobRect == null)
            {
                return;
            }

            Rect rect = zoneRect.rect;
            dynamicCenter = new Vector2(rect.xMin + Mathf.Min(165f, rect.width * 0.42f), rect.center.y);
            baseRect.anchoredPosition = dynamicCenter;
            knobRect.anchoredPosition = dynamicCenter;
            baseImage.color = new Color(0.07f, 0.22f, 0.38f, 0.42f);
            knobImage.color = new Color(0.18f, 0.62f, 0.95f, 0.62f);
        }

        public void OnPointerDown(PointerEventData eventData)
        {
            if (activePointer != int.MinValue)
            {
                return;
            }

            activePointer = eventData.pointerId;
            Vector2 local = ScreenToLocal(eventData);
            dynamicCenter = ClampCenter(local);
            baseRect.anchoredPosition = dynamicCenter;
            knobRect.anchoredPosition = dynamicCenter;
            baseImage.color = new Color(0.07f, 0.30f, 0.50f, 0.82f);
            knobImage.color = new Color(0.20f, 0.72f, 1f, 1f);
            player?.SetMoveAxis(Vector2.zero);
        }

        public void OnDrag(PointerEventData eventData)
        {
            if (eventData.pointerId != activePointer)
            {
                return;
            }

            Vector2 local = ScreenToLocal(eventData);
            Vector2 delta = local - dynamicCenter;
            float distance = delta.magnitude;

            if (distance > radius * 1.16f && distance > 0.001f)
            {
                float shift = distance - radius * 1.16f;
                dynamicCenter = ClampCenter(dynamicCenter + delta.normalized * shift);
                baseRect.anchoredPosition = dynamicCenter;
                delta = local - dynamicCenter;
                distance = delta.magnitude;
            }

            Vector2 clamped = distance > radius ? delta.normalized * radius : delta;
            knobRect.anchoredPosition = dynamicCenter + clamped;

            Vector2 raw = clamped / radius;
            float magnitude = raw.magnitude;
            Vector2 output = Vector2.zero;
            if (magnitude > deadzone)
            {
                float remapped = Mathf.Clamp01((magnitude - deadzone) / (1f - deadzone));
                output = raw.normalized * Mathf.Pow(remapped, 0.82f);
            }

            player?.SetMoveAxis(output);
        }

        public void OnPointerUp(PointerEventData eventData)
        {
            if (eventData.pointerId != activePointer)
            {
                return;
            }

            activePointer = int.MinValue;
            player?.SetMoveAxis(Vector2.zero);
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

        private Vector2 ClampCenter(Vector2 local)
        {
            Rect rect = zoneRect.rect;
            float padding = radius + 5f;
            return new Vector2(
                Mathf.Clamp(local.x, rect.xMin + padding, rect.xMax - padding),
                Mathf.Clamp(local.y, rect.yMin + padding, rect.yMax - padding));
        }

        private static Sprite CreateCircleSprite(int size)
        {
            Texture2D texture = new Texture2D(size, size, TextureFormat.RGBA32, false);
            texture.name = "RuntimeCircle";
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

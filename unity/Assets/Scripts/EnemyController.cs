using UnityEngine;

namespace SuperChkBros
{
    public sealed class EnemyController : MonoBehaviour
    {
        private float leftBoundary;
        private float rightBoundary;
        private float speed;
        private int hitPoints;
        private int direction = 1;
        private SpriteRenderer spriteRenderer;

        public bool IsBoss => hitPoints > 1 || gameObject.name == "Boss";

        public void Configure(float left, float right, int health, float moveSpeed)
        {
            leftBoundary = Mathf.Min(left, right);
            rightBoundary = Mathf.Max(left, right);
            hitPoints = Mathf.Max(1, health);
            speed = Mathf.Max(0.4f, moveSpeed);
            spriteRenderer = GetComponent<SpriteRenderer>();
        }

        private void Awake()
        {
            spriteRenderer = GetComponent<SpriteRenderer>();
        }

        private void FixedUpdate()
        {
            if (Time.timeScale <= 0f)
            {
                return;
            }

            Vector3 position = transform.position;
            position.x += direction * speed * Time.fixedDeltaTime;
            if (position.x <= leftBoundary)
            {
                position.x = leftBoundary;
                direction = 1;
            }
            else if (position.x >= rightBoundary)
            {
                position.x = rightBoundary;
                direction = -1;
            }

            transform.position = position;
            if (spriteRenderer != null)
            {
                spriteRenderer.flipX = direction < 0;
            }
        }

        public void Stomp()
        {
            hitPoints--;
            if (hitPoints <= 0)
            {
                bool boss = gameObject.name == "Boss";
                SuperChkGame.Instance.AddEnemyScore(boss);
                Destroy(gameObject);
            }
            else
            {
                speed *= 1.18f;
                transform.localScale *= 0.92f;
                if (spriteRenderer != null)
                {
                    spriteRenderer.color = Color.Lerp(spriteRenderer.color, Color.red, 0.35f);
                }
            }
        }
    }
}

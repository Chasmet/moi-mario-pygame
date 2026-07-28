using System.Collections;
using UnityEngine;

namespace SuperChkBros
{
    public sealed class PlayerController : MonoBehaviour
    {
        private const float MaxSpeed = 7.2f;
        private const float GroundAcceleration = 58f;
        private const float AirAcceleration = 40f;
        private const float GroundDeceleration = 64f;
        private const float AirDeceleration = 24f;
        private const float JumpVelocity = 12.7f;
        private const float MaxFallSpeed = 18f;
        private const float CoyoteDuration = 0.22f;
        private const float JumpBufferDuration = 0.24f;
        private const float CrouchSpeedFactor = 0.48f;

        private SpriteRenderer spriteRenderer;
        private Rigidbody2D body;
        private BoxCollider2D bodyCollider;
        private Vector2 moveAxis;
        private Vector2 standingSize;
        private Vector2 standingOffset;
        private Vector3 normalScale;
        private float coyoteTimer;
        private float jumpBufferTimer;
        private float invincibleTimer;
        private bool jumpHeld;
        private bool crouching;
        private bool lookingUp;
        private bool grounded;

        public bool IsInvincible => invincibleTimer > 0f;

        public void Configure(SpriteRenderer renderer, Rigidbody2D rigidbody2D, BoxCollider2D collider2D)
        {
            spriteRenderer = renderer;
            body = rigidbody2D;
            bodyCollider = collider2D;
            standingSize = collider2D.size;
            standingOffset = collider2D.offset;
            normalScale = renderer.transform.localScale;
        }

        public void SetMoveAxis(Vector2 axis)
        {
            moveAxis = Vector2.ClampMagnitude(axis, 1f);
        }

        public void PressJump()
        {
            jumpHeld = true;
            jumpBufferTimer = JumpBufferDuration;
        }

        public void ReleaseJump()
        {
            jumpHeld = false;
            if (body != null && body.linearVelocity.y > 3.2f)
            {
                Vector2 velocity = body.linearVelocity;
                velocity.y *= 0.58f;
                body.linearVelocity = velocity;
            }
        }

        public void ResetMotion()
        {
            if (body != null)
            {
                body.linearVelocity = Vector2.zero;
                body.angularVelocity = 0f;
            }
            moveAxis = Vector2.zero;
            jumpHeld = false;
            jumpBufferTimer = 0f;
            SetCrouching(false);
        }

        public void SetInvincible(float duration)
        {
            invincibleTimer = Mathf.Max(invincibleTimer, duration);
        }

        private void Update()
        {
            if (body == null || bodyCollider == null)
            {
                return;
            }

            if (transform.position.y < -8f)
            {
                SuperChkGame.Instance.PlayerDamaged();
            }

            if (invincibleTimer > 0f)
            {
                invincibleTimer = Mathf.Max(0f, invincibleTimer - Time.deltaTime);
                spriteRenderer.enabled = Mathf.FloorToInt(invincibleTimer * 16f) % 2 == 0;
            }
            else
            {
                spriteRenderer.enabled = true;
            }

            UpdateVisuals();
        }

        private void FixedUpdate()
        {
            if (body == null || Time.timeScale <= 0f)
            {
                return;
            }

            grounded = CheckGrounded();
            if (grounded)
            {
                coyoteTimer = CoyoteDuration;
            }
            else
            {
                coyoteTimer = Mathf.Max(0f, coyoteTimer - Time.fixedDeltaTime);
            }

            jumpBufferTimer = Mathf.Max(0f, jumpBufferTimer - Time.fixedDeltaTime);
            UpdateStance();
            TryJump();
            ApplyMovement();
            ApplyBetterGravity();
        }

        private bool CheckGrounded()
        {
            Bounds bounds = bodyCollider.bounds;
            RaycastHit2D[] hits = Physics2D.BoxCastAll(
                bounds.center,
                new Vector2(bounds.size.x * 0.82f, bounds.size.y * 0.92f),
                0f,
                Vector2.down,
                0.09f);

            foreach (RaycastHit2D hit in hits)
            {
                if (hit.collider != null && hit.collider != bodyCollider && !hit.collider.isTrigger)
                {
                    return true;
                }
            }
            return false;
        }

        private void UpdateStance()
        {
            float horizontal = Mathf.Abs(moveAxis.x);
            float vertical = Mathf.Abs(moveAxis.y);
            bool verticalDominant = vertical > 0.30f && vertical >= horizontal * 0.72f;
            bool wantsCrouch = grounded && verticalDominant && moveAxis.y < -0.12f;
            lookingUp = grounded && verticalDominant && moveAxis.y > 0.12f && !wantsCrouch;
            SetCrouching(wantsCrouch);
        }

        private void SetCrouching(bool value)
        {
            if (crouching == value || bodyCollider == null)
            {
                return;
            }

            crouching = value;
            if (crouching)
            {
                bodyCollider.size = new Vector2(standingSize.x, standingSize.y * 0.62f);
                bodyCollider.offset = standingOffset + Vector2.down * (standingSize.y * 0.19f);
            }
            else
            {
                bodyCollider.size = standingSize;
                bodyCollider.offset = standingOffset;
            }
        }

        private void TryJump()
        {
            if (jumpBufferTimer <= 0f || coyoteTimer <= 0f)
            {
                return;
            }

            SetCrouching(false);
            lookingUp = false;
            Vector2 velocity = body.linearVelocity;
            velocity.y = JumpVelocity;
            body.linearVelocity = velocity;
            jumpBufferTimer = 0f;
            coyoteTimer = 0f;
        }

        private void ApplyMovement()
        {
            float horizontal = Mathf.Abs(moveAxis.x) < 0.035f ? 0f : moveAxis.x;
            float speedFactor = crouching ? CrouchSpeedFactor : 1f;
            float targetSpeed = horizontal * MaxSpeed * speedFactor;
            Vector2 velocity = body.linearVelocity;

            float acceleration;
            if (Mathf.Abs(horizontal) > 0.001f)
            {
                acceleration = grounded ? GroundAcceleration : AirAcceleration;
            }
            else
            {
                acceleration = grounded ? GroundDeceleration : AirDeceleration;
            }

            velocity.x = Mathf.MoveTowards(velocity.x, targetSpeed, acceleration * Time.fixedDeltaTime);
            velocity.y = Mathf.Max(velocity.y, -MaxFallSpeed);
            body.linearVelocity = velocity;
        }

        private void ApplyBetterGravity()
        {
            Vector2 velocity = body.linearVelocity;
            if (velocity.y < -0.1f)
            {
                body.AddForce(Physics2D.gravity * 0.20f, ForceMode2D.Force);
            }
            else if (velocity.y > 0.1f && !jumpHeld)
            {
                body.AddForce(Physics2D.gravity * 0.62f, ForceMode2D.Force);
            }
            else if (Mathf.Abs(velocity.y) < 1.1f && !grounded)
            {
                body.AddForce(-Physics2D.gravity * 0.34f, ForceMode2D.Force);
            }
        }

        private void UpdateVisuals()
        {
            if (spriteRenderer == null || body == null)
            {
                return;
            }

            if (Mathf.Abs(moveAxis.x) > 0.04f)
            {
                spriteRenderer.flipX = moveAxis.x < 0f;
            }

            Vector3 targetScale = normalScale;
            float targetRotation = Mathf.Clamp(body.linearVelocity.x / MaxSpeed, -1f, 1f) * -3f;
            if (crouching)
            {
                targetScale = new Vector3(normalScale.x * 1.08f, normalScale.y * 0.68f, normalScale.z);
            }
            else if (lookingUp)
            {
                targetScale = new Vector3(normalScale.x * 0.98f, normalScale.y * 1.05f, normalScale.z);
                targetRotation = spriteRenderer.flipX ? -3f : 3f;
            }
            else if (!grounded)
            {
                targetScale = new Vector3(normalScale.x * 0.96f, normalScale.y * 1.04f, normalScale.z);
            }

            spriteRenderer.transform.localScale = Vector3.Lerp(spriteRenderer.transform.localScale, targetScale, Time.deltaTime * 14f);
            spriteRenderer.transform.localRotation = Quaternion.Lerp(
                spriteRenderer.transform.localRotation,
                Quaternion.Euler(0f, 0f, targetRotation),
                Time.deltaTime * 12f);
        }

        private void OnCollisionEnter2D(Collision2D collision)
        {
            EnemyController enemy = collision.collider.GetComponent<EnemyController>();
            if (enemy == null)
            {
                return;
            }

            bool falling = body.linearVelocity.y < -0.1f;
            bool aboveEnemy = transform.position.y > enemy.transform.position.y + 0.35f;
            if (falling && aboveEnemy)
            {
                enemy.Stomp();
                Vector2 velocity = body.linearVelocity;
                velocity.y = 8.8f;
                body.linearVelocity = velocity;
            }
            else if (!IsInvincible)
            {
                SuperChkGame.Instance.PlayerDamaged();
            }
        }
    }
}

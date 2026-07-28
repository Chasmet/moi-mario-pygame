using UnityEngine;

namespace SuperChkBros
{
    public sealed class CameraFollow : MonoBehaviour
    {
        private Transform target;
        private Vector3 velocity;

        public void SetTarget(Transform followTarget)
        {
            target = followTarget;
        }

        private void LateUpdate()
        {
            if (target == null || SuperChkGame.Instance == null)
            {
                return;
            }

            float maxX = Mathf.Max(2f, SuperChkGame.Instance.LevelWidth - 3.5f);
            float desiredX = Mathf.Clamp(target.position.x + 1.45f, 2f, maxX);
            float desiredY = Mathf.Clamp(target.position.y + 1.15f, -0.2f, 2.35f);
            Vector3 desired = new Vector3(desiredX, desiredY, -10f);
            transform.position = Vector3.SmoothDamp(transform.position, desired, ref velocity, 0.075f, 40f, Time.unscaledDeltaTime);
        }
    }
}

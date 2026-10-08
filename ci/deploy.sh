#!/usr/bin/env bash
set -euo pipefail
namespace=$1
case "$namespace" in dev|qa|staging|prod) ;; *) exit 2;; esac
# Existing Secret must contain movie-uri, cast-uri, movie-password, cast-password.
kubectl -n "$namespace" get secret cinema-database-credentials >/dev/null
helm upgrade --install cinema charts -n "$namespace" --set-string registry="$REGISTRY" --set-string tag="$IMAGE_TAG" --wait --rollback-on-failure --timeout 5m
kubectl -n "$namespace" rollout status deployment/cinema-movie-service --timeout=120s
kubectl -n "$namespace" rollout status deployment/cinema-cast-service --timeout=120s
kubectl -n "$namespace" port-forward service/cinema-gateway 18080:8080 > port-forward.log 2>&1 &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true' EXIT
# Quiet retries while the tunnel starts; retain the last error for a real failure.
last_error=$(mktemp)
trap 'kill "$forward_pid" 2>/dev/null || true; rm -f "$last_error"' EXIT
for attempt in {1..30}; do
  if ! kill -0 "$forward_pid" 2>/dev/null; then
    echo "Port-forward exited before health checks completed" >&2
    cat port-forward.log >&2
    exit 1
  fi
  if curl --connect-timeout 2 --max-time 5 -fsS http://127.0.0.1:18080/api/v1/movies/ > /dev/null 2> "$last_error" &&
     curl --connect-timeout 2 --max-time 5 -fsS http://127.0.0.1:18080/api/v1/casts/openapi.json > /dev/null 2> "$last_error"; then
    echo "PASS: $namespace rollout and gateway health checks completed"
    exit 0
  fi
  sleep 2
done
echo "FAIL: $namespace gateway did not become healthy" >&2
cat "$last_error" port-forward.log >&2
exit 1

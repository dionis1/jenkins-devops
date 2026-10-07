#!/usr/bin/env bash
set -euo pipefail
namespace=$1
case "$namespace" in dev|qa|staging|prod) ;; *) exit 2;; esac
# Existing Secret must contain movie-uri, cast-uri, movie-password, cast-password.
kubectl -n "$namespace" get secret database-credentials >/dev/null
helm upgrade --install cinema charts -n "$namespace" --set-string registry="$REGISTRY" --set-string tag="$IMAGE_TAG" --wait --rollback-on-failure --timeout 5m
kubectl -n "$namespace" rollout status deployment/movie-service --timeout=120s
kubectl -n "$namespace" rollout status deployment/cast-service --timeout=120s
kubectl -n "$namespace" port-forward service/gateway 18080:8080 > port-forward.log 2>&1 &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true' EXIT
# Deployment smoke checks avoid writing test records into production.
for attempt in {1..30}; do
  if curl -fsS http://127.0.0.1:18080/api/v1/movies/ >/dev/null && curl -fsS http://127.0.0.1:18080/api/v1/casts/openapi.json >/dev/null; then exit 0; fi
  sleep 2
done
exit 1

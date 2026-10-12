#!/usr/bin/env bash
set -euo pipefail
: "${JENKINS_AGENT_SECRET_FILE:?Set path to the local inbound-agent secret file}"
: "${JENKINS_AGENT_NAME:=exam-agent}"
: "${JENKINS_URL:=http://jenkins:8080}"
: "${JAVA_BIN:=java}"
: "${AGENT_WORKDIR:=/home/jenkins/agent}"
mkdir -p "$AGENT_WORKDIR"
# Wait for the separate rootless daemon after controller/host restarts.
for attempt in {1..60}; do
  if docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then break; fi
  sleep 2
done
if ! docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then
  echo 'Docker daemon did not become ready' >&2
  exit 1
fi
# Refresh remoting from the controller on each start. Retry while it starts up.
curl --fail --silent --show-error --retry 60 --retry-all-errors --retry-delay 2 \
  "$JENKINS_URL/jnlpJars/agent.jar" -o "$AGENT_WORKDIR/agent.jar"
exec "$JAVA_BIN" -jar "$AGENT_WORKDIR/agent.jar" -url "$JENKINS_URL" \
  -secret "@$JENKINS_AGENT_SECRET_FILE" -name "$JENKINS_AGENT_NAME" \
  -webSocket -workDir "$AGENT_WORKDIR"

#!/usr/bin/env bash
set -euo pipefail
# Jenkins node must be named exam-agent and labeled docker-kubernetes.
# Store its inbound secret in a private local file outside the repository.
: "${JENKINS_AGENT_SECRET_FILE:?Set path to the local inbound-agent secret file}"
: "${JENKINS_AGENT_NAME:=exam-agent}"
: "${JENKINS_URL:=http://127.0.0.1:8081}"
: "${JAVA_BIN:=/tmp/exam-jenkins-java/bin/java}"
: "${AGENT_JAR:=/tmp/exam-jenkins-agent.jar}"
: "${AGENT_WORKDIR:=/tmp/exam-jenkins-agent}"
exec "$JAVA_BIN" -jar "$AGENT_JAR" -url "$JENKINS_URL" -secret "@$JENKINS_AGENT_SECRET_FILE" -name "$JENKINS_AGENT_NAME" -webSocket -workDir "$AGENT_WORKDIR"

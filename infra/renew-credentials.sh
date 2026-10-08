#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Run as the workstation administrator, never as a Jenkins build step.
python3 infra/generate-kubeconfigs.py --output-dir .jenkins-local/credentials "$@"
# Copy each file into its controller volume; they are never mounted on build agents.
docker compose -f infra/jenkins-compose.yaml cp .jenkins-local/credentials/nonprod.json jenkins:/var/jenkins_home/exam-kubeconfig.json
docker compose -f infra/jenkins-compose.yaml cp .jenkins-local/credentials/prod.json production:/var/jenkins_home/exam-kubeconfig.json
for service in jenkins production; do
  docker compose -f infra/jenkins-compose.yaml exec -T -u root "$service" sh -c 'chown jenkins:jenkins /var/jenkins_home/exam-kubeconfig.json; chmod 600 /var/jenkins_home/exam-kubeconfig.json'
done
# The startup hooks replace the stored Secret File credentials. Wait for builds to finish first.
docker compose -f infra/jenkins-compose.yaml restart jenkins production
printf '%s\n' 'Renewed both credentials. Wait for both Jenkins instances to finish restarting.'

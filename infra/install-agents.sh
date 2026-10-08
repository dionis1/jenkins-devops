#!/usr/bin/env bash
# Run once on the workstation after configuring/authenticating the main Jenkins.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p .jenkins-local
compose=(docker compose -f infra/jenkins-compose.yaml)
"${compose[@]}" build agent
# Clone authentication and installed plugins only, never build jobs or credentials.
"${compose[@]}" create production
main_id=$("${compose[@]}" ps -q jenkins)
prod_id=$("${compose[@]}" ps -aq production)
test -n "$main_id"
if [[ ! -f .jenkins-local/production-seeded ]]; then
  for item in config.xml users plugins; do
    docker cp "$main_id:/var/jenkins_home/$item" - | docker cp - "$prod_id:/var/jenkins_home/"
  done
  touch .jenkins-local/production-seeded
fi
# Node exam-agent must already exist in the main Jenkins.
# Read only its remoting secret, generated during the initial node setup.
"${compose[@]}" cp jenkins:/var/jenkins_home/exam-agent.secret .jenkins-local/agent-secret
chmod 600 .jenkins-local/agent-secret
python3 infra/generate-kubeconfigs.py --output-dir .jenkins-local/credentials
"${compose[@]}" cp .jenkins-local/credentials/nonprod.json jenkins:/var/jenkins_home/exam-kubeconfig.json
"${compose[@]}" cp .jenkins-local/credentials/prod.json production:/var/jenkins_home/exam-kubeconfig.json
# Jenkins runs as uid 1000 in both images. Fix ownership before starting production.
"${compose[@]}" run --rm --no-deps -u root --entrypoint sh production -c 'chown -R 1000:1000 /var/jenkins_home; chmod 600 /var/jenkins_home/exam-kubeconfig.json'
"${compose[@]}" exec -T -u root jenkins sh -c 'chown 1000:1000 /var/jenkins_home/exam-kubeconfig.json; chmod 600 /var/jenkins_home/exam-kubeconfig.json'
"${compose[@]}" up -d jenkins docker production
# Stop only the legacy exam agent, leaving other Java processes alone.
python3 - <<'PYTHON'
import os, signal
from pathlib import Path
for path in Path('/proc').iterdir():
    if not path.name.isdigit():
        continue
    try:
        args = (path / 'cmdline').read_bytes().split(b'\0')
        if args and args[0] == b'/tmp/exam-jenkins-java/bin/java' and b'/tmp/exam-jenkins-agent.jar' in args:
            os.kill(int(path.name), signal.SIGTERM)
    except (OSError, PermissionError):
        pass
PYTHON
"${compose[@]}" run --rm --no-deps -u root --entrypoint sh agent -c 'chown -R 1000:1000 /home/jenkins/agent'
"${compose[@]}" up -d agent
printf '%s\n' 'Build Jenkins: http://localhost:8081' 'Production Jenkins: http://localhost:8082 (same initial admin login)'

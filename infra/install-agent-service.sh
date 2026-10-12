#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
repo=$(pwd -P)
run_user=$(id -un)
run_group=docker
unit=/etc/systemd/system/exam-jenkins-agent.service
sudo tee "$unit" >/dev/null <<EOF
[Unit]
Description=Persistent isolated Jenkins build agent
Requires=docker.service apparmor.service
After=docker.service apparmor.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=$run_user
Group=$run_group
WorkingDirectory=$repo
ExecStartPre=/usr/bin/docker compose -f infra/jenkins-compose.yaml rm --force agent docker
ExecStart=/usr/bin/docker compose -f infra/jenkins-compose.yaml up --detach docker agent
ExecStop=/usr/bin/docker compose -f infra/jenkins-compose.yaml stop agent docker
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now exam-jenkins-agent.service

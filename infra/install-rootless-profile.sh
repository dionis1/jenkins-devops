#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
sudo install -m 644 rootless-apparmor /etc/apparmor.d/exam-jenkins-rootless
sudo apparmor_parser -r /etc/apparmor.d/exam-jenkins-rootless
printf '%s\n' 'Loaded the AppArmor profile for the rootless Jenkins build daemon.'

"""Regression checks for credential isolation and rollout startup diagnostics."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


class InfrastructureTests(unittest.TestCase):
    def test_generated_configs_exclude_admin_identity(self):
        spec = importlib.util.spec_from_file_location('credentials', ROOT / 'infra/generate-kubeconfigs.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        source = {'clusters': [{'name': 'test', 'cluster': {
            'server': 'https://cluster:6443', 'certificate-authority-data': 'public-ca'}}],
            'users': [{'name': 'admin', 'user': {'client-key-data': 'ADMIN-PRIVATE-KEY'}}]}
        def kubectl(*args):
            return json.dumps(source) if args[0] == 'config' else 'scoped-' + args[4]
        with tempfile.TemporaryDirectory() as directory:
            output = io.StringIO()
            old_mask = os.umask(0o077)
            try:
                with patch.object(module, 'kubectl', side_effect=kubectl), patch('sys.argv',
                        ['generate-kubeconfigs.py', '--output-dir', directory]), contextlib.redirect_stdout(output):
                    module.main()
            finally:
                os.umask(old_mask)
            for filename, namespace, account in [('nonprod.json', 'dev', 'jenkins-nonprod'),
                                                  ('prod.json', 'prod', 'jenkins-prod')]:
                path = Path(directory) / filename
                value = json.loads(path.read_text())
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
                self.assertEqual(value['contexts'][0]['context']['namespace'], namespace)
                self.assertEqual(value['users'], [{'name': account, 'user': {'token': 'scoped-' + account}}])
                self.assertNotIn('ADMIN-PRIVATE-KEY', path.read_text())
            self.assertNotIn('scoped-', output.getvalue())

    def rollout(self, curl_body):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            commands = {
                'helm': 'exit 0',
                'kubectl': 'if [[ "$*" == *port-forward* ]]; then exec /bin/sleep 60; fi\nexit 0',
                'sleep': 'exec /bin/sleep 0.01',
                'curl': curl_body,
            }
            for name, body in commands.items():
                command = root / name
                command.write_text('#!/bin/bash\n' + body + '\n')
                command.chmod(0o700)
            return subprocess.run(['bash', str(ROOT / 'ci/deploy.sh'), 'dev'], cwd=root,
                                  env={**os.environ, 'PATH': directory + ':' + os.environ['PATH'],
                                       'REGISTRY': 'test', 'IMAGE_TAG': 'test'},
                                  text=True, capture_output=True, timeout=10)

    def test_tunnel_startup_retry_is_quiet(self):
        result = self.rollout('if [[ ! -f attempted ]]; then touch attempted; echo "connection refused" >&2; exit 7; fi\nexit 0')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('PASS: dev', result.stdout)
        self.assertNotIn('connection refused', result.stderr)

    def test_real_health_failure_remains_visible(self):
        result = self.rollout('echo "connection refused" >&2; exit 7')
        self.assertEqual(result.returncode, 1)
        self.assertIn('FAIL: dev', result.stderr)
        self.assertIn('connection refused', result.stderr)


if __name__ == '__main__':
    unittest.main()

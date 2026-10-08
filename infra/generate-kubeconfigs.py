#!/usr/bin/env python3
"""Create renewable, namespace-scoped Jenkins kubeconfigs without printing tokens."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile


def kubectl(*args):
    return subprocess.check_output(['kubectl', *args], text=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--duration', default='24h')
    args = parser.parse_args()
    os.umask(0o077)
    args.output_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    config = json.loads(kubectl('config', 'view', '--minify', '--flatten', '--raw', '-o', 'json'))
    cluster = config['clusters'][0]
    # Copy only the public cluster connection/CA data; never the administrator identity.
    connection = {key: value for key, value in cluster['cluster'].items()
                  if key in ('server', 'certificate-authority-data', 'tls-server-name')}
    if 'certificate-authority-data' not in connection:
        raise SystemExit('Cluster must provide a trusted certificate authority')
    for filename, namespace, account in [('nonprod.json', 'dev', 'jenkins-nonprod'),
                                         ('prod.json', 'prod', 'jenkins-prod')]:
        token = kubectl('-n', namespace, 'create', 'token', account,
                        '--duration=' + args.duration).strip()
        scoped = {'apiVersion': 'v1', 'kind': 'Config',
                  'clusters': [{'name': cluster['name'], 'cluster': connection}],
                  'users': [{'name': account, 'user': {'token': token}}],
                  'contexts': [{'name': 'exam', 'context': {'cluster': cluster['name'],
                                'user': account, 'namespace': namespace}}],
                  'current-context': 'exam'}
        fd, temporary = tempfile.mkstemp(dir=args.output_dir)
        try:
            with os.fdopen(fd, 'w') as output:
                json.dump(scoped, output)
            os.replace(temporary, args.output_dir / filename)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        print('Created ' + str(args.output_dir / filename) + ' (requested lifetime: ' + args.duration + ')')


if __name__ == '__main__':
    main()

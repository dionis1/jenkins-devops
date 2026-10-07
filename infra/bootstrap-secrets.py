"""Create independent exam database secrets without printing their contents."""
import json
import secrets
import subprocess

for namespace in ('dev', 'qa', 'staging', 'prod'):
    result = subprocess.run(['kubectl', '-n', namespace, 'get', 'secret',
                             'cinema-database-credentials', '--ignore-not-found', '-o', 'name'],
                            capture_output=True, text=True, check=True)
    if result.stdout.strip():
        print(namespace + ': retaining existing exam database secret')
        continue
    data = {}
    for service in ('movie', 'cast'):
        password = secrets.token_hex(24)
        data[service + '-password'] = password
        data[service + '-uri'] = (
            f'postgresql://{service}_db_username:{password}'
            f'@cinema-{service}-db/{service}_db_dev')
    manifest = {'apiVersion': 'v1', 'kind': 'Secret',
                'metadata': {'name': 'cinema-database-credentials', 'namespace': namespace},
                'type': 'Opaque', 'stringData': data}
    subprocess.run(['kubectl', 'create', '-f', '-'], input=json.dumps(manifest),
                   text=True, stdout=subprocess.DEVNULL, check=True)
    print(namespace + ': created exam database secret')

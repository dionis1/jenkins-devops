"""Package actual exam evidence; never manufacture missing results."""
import re
import sys
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

if len(sys.argv) != 5:
    raise SystemExit('Usage: python3 ci/package.py FIRST LAST CLASS YEAR')
root = Path(__file__).resolve().parents[1] / 'deliverables'
files = [root / name for name in ('github.txt', 'dockerhub.txt', 'jenkins-results.pdf')]
for file in files:
    if not file.is_file():
        raise SystemExit('Missing required evidence: ' + str(file))
for file, prefix in zip(files[:2], ('https://github.com/', 'https://hub.docker.com/')):
    url = file.read_text().strip()
    if not url.startswith(prefix) or any(word in url.lower() for word in ('replace', 'your_', 'placeholder', 'datascientest/jenkins_devops_exams')):
        raise SystemExit('Provide your real account URL in ' + str(file))
if not files[2].read_bytes().startswith(b'%PDF-'):
    raise SystemExit('Jenkins results must be a PDF')
parts = [re.sub(r'[^a-z0-9_-]+', '_', value.lower()).strip('_') for value in sys.argv[1:]]
if not all(parts):
    raise SystemExit('All filename fields are required')
output = root / ('_'.join(parts) + '.zip')
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for file in files:
        archive.write(file, file.name)
print(output)

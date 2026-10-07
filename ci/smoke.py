import json, sys, time, urllib.request, urllib.error
base=sys.argv[1].rstrip('/')
def request(path, data=None):
    body=None if data is None else json.dumps(data).encode()
    req=urllib.request.Request(base+path, data=body, headers={'Content-Type':'application/json'})
    with urllib.request.urlopen(req, timeout=10) as response:
        return json.load(response)
for attempt in range(60):
    try:
        request('/api/v1/movies/openapi.json')
        request('/api/v1/casts/openapi.json')
        break
    except (OSError, ValueError):
        time.sleep(2)
else:
    raise RuntimeError('APIs did not become ready')
cast=request('/api/v1/casts/', {'name':'CI actor','nationality':'Test'})
assert request('/api/v1/casts/%s/' % cast['id'])['name']=='CI actor'
movie=request('/api/v1/movies/', {'name':'CI movie','plot':'Integration test','genres':['test'],'casts_id':[cast['id']]})
assert request('/api/v1/movies/%s/' % movie['id'])['casts_id']==[cast['id']]
try:
    request('/api/v1/movies/', {'name':'Invalid','plot':'test','genres':[],'casts_id':[2147483647]})
    raise AssertionError('Missing cast was accepted')
except urllib.error.HTTPError as error:
    assert error.code==404
print('PASS: API schemas, database writes/reads, cross-service validation')

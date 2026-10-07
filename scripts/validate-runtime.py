#!/usr/bin/env python3
"""Explicitly requested local runtime checks; credentials never printed."""
import html
import json
import re
from pathlib import Path
import requests

ROOT = Path(__file__).resolve().parents[1]
ENV = dict(line.split('=', 1) for line in (ROOT / '.env').read_text().splitlines() if line and not line.startswith('#') and '=' in line)
BASE = 'http://127.0.0.1:8081'

def login(prefix):
    session = requests.Session()
    page = session.get(BASE + '/login/canvas', timeout=60)
    token = re.search(r'name="authenticity_token"[^>]*value="([^"]+)"', page.text)
    assert token, 'Login CSRF token missing'
    response = session.post(BASE + '/login/canvas', data={
        'authenticity_token': html.unescape(token.group(1)),
        'pseudonym_session[unique_id]': ENV[prefix + '_EMAIL'],
        'pseudonym_session[password]': ENV[prefix + '_PASSWORD'],
    }, timeout=60)
    response.raise_for_status()
    csrf = session.cookies.get('_csrf_token')
    if csrf:
        from urllib.parse import unquote
        session.headers['X-CSRF-Token'] = unquote(csrf)
    me = session.get(BASE + '/api/v1/users/self/profile', timeout=60)
    me.raise_for_status()
    return session, me.json()

results = {'roles': {}}
for role, prefix in [('admin', 'CANVAS_LMS_ADMIN'), ('tutor', 'CANVAS_LOCAL_TUTOR'), ('wb', 'CANVAS_LOCAL_WB')]:
    session, profile = login(prefix)
    course = session.get(BASE + '/api/v1/courses/1', timeout=60)
    course.raise_for_status()
    permissions = session.get(BASE + '/api/v1/courses/1/permissions', params=[('permissions[]', 'manage_assignments_add'), ('permissions[]', 'manage_files_add'), ('permissions[]', 'manage_grades')], timeout=60)
    permissions.raise_for_status()
    results['roles'][role] = {'name': profile['name'], 'course_id': course.json()['id'], 'permissions': permissions.json()}
    if role == 'admin':
        admin_session = session
    if role == 'wb':
        assert not any(permissions.json().values()), 'WB unexpectedly has management permissions'
    if role == 'tutor':
        assert permissions.json()['manage_grades'], 'Tutor cannot manage grades'

fixture = ROOT / 'var/validation/cek-unggahan.txt'
import sys
if '--persist' in sys.argv:
    previous = json.loads((ROOT / 'var/validation/runtime-api.json').read_text())
    stored = admin_session.get(BASE + '/api/v1/files/' + str(previous['upload']['file_id']), timeout=60)
    stored.raise_for_status()
    record = stored.json()
    results['persistence_after_restart'] = True
else:
    init = admin_session.post(BASE + '/api/v1/courses/2/files', data={'name': fixture.name, 'size': fixture.stat().st_size, 'content_type': 'text/plain', 'on_duplicate': 'overwrite'}, timeout=60)
    init.raise_for_status()
    info = init.json()
    assert info['upload_url'].startswith(BASE + '/'), 'Upload destination outside local Canvas'
    with fixture.open('rb') as stream:
        uploaded = admin_session.post(info['upload_url'], data=info['upload_params'], files={'file': (fixture.name, stream, 'text/plain')}, timeout=60)
    uploaded.raise_for_status()
    record = uploaded.json()
download = admin_session.get(record['url'], timeout=60)
download.raise_for_status()
assert download.content == fixture.read_bytes(), 'Uploaded/downloaded bytes differ'
results['upload'] = {'course_id': 2, 'file_id': record['id'], 'filename': record['filename'], 'bytes_match': True}
catalog = requests.get('http://127.0.0.1:3000/api/v1/catalog', timeout=60)
catalog.raise_for_status()
results['catalog'] = catalog.json()
out = ROOT / ('var/validation/runtime-persistence.json' if '--persist' in sys.argv else 'var/validation/runtime-api.json')
out.write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'roles': results['roles'], 'upload': results['upload'], 'catalog_http': catalog.status_code}, ensure_ascii=False, indent=2))

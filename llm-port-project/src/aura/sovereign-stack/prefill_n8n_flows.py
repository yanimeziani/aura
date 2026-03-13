#!/usr/bin/env python3
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_FLOW_FILES = [
    ROOT / 'ai_agency_wealth' / 'n8n_micro_saas_fulfillment.json',
    ROOT / 'vault' / 'n8n_zero_inbox_blueprint.json',
]


def _headers() -> dict[str, str]:
    api_key = os.environ.get('N8N_API_KEY', '').strip()
    if not api_key:
        raise RuntimeError('N8N_API_KEY is missing. Set it in environment or .env.local.')
    return {
        'Content-Type': 'application/json',
        'X-N8N-API-KEY': api_key,
    }


def _request(method: str, path: str, body: dict | None = None) -> dict:
    base = os.environ.get('N8N_BASE_URL', 'http://127.0.0.1:5678').rstrip('/')
    url = f'{base}{path}'
    data = None if body is None else json.dumps(body).encode('utf-8')
    req = urllib.request.Request(url=url, data=data, method=method, headers=_headers())
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read().decode('utf-8')
        return json.loads(raw) if raw else {}


def _normalize(workflow: dict) -> dict:
    allowed = {
        'name',
        'nodes',
        'connections',
        'settings',
        'staticData',
        'pinData',
        'meta',
        'active',
    }
    clean = {k: workflow[k] for k in workflow.keys() if k in allowed}
    clean['active'] = False
    if 'settings' not in clean:
        clean['settings'] = {}
    return clean


def _list_workflows() -> list[dict]:
    out = _request('GET', '/api/v1/workflows?limit=250')
    if isinstance(out, dict):
        if isinstance(out.get('data'), list):
            return out['data']
        if isinstance(out.get('workflows'), list):
            return out['workflows']
    return []


def upsert_workflow(flow_path: Path) -> None:
    workflow = json.loads(flow_path.read_text(encoding='utf-8'))
    payload = _normalize(workflow)
    name = payload.get('name') or flow_path.stem
    payload['name'] = name

    existing = _list_workflows()
    match = next((w for w in existing if w.get('name') == name), None)

    if match and match.get('id'):
        workflow_id = str(match['id'])
        _request('PATCH', f'/api/v1/workflows/{urllib.parse.quote(workflow_id)}', payload)
        print(f'updated: {name} ({workflow_id})')
        return

    created = _request('POST', '/api/v1/workflows', payload)
    print(f'created: {name} ({created.get("id", "unknown-id")})')


def main() -> int:
    failures = 0
    for path in DEFAULT_FLOW_FILES:
        if not path.exists():
            print(f'skipped: missing {path}')
            continue
        try:
            upsert_workflow(path)
        except (RuntimeError, urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError) as exc:
            failures += 1
            print(f'failed: {path.name}: {exc}')

    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())

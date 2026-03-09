# Mission Control

**One place.** Repo root. You run from here; the agent executes.

```bash
./run          # usage + two-letter aliases
./run lp       # launch (deploy + test) on this machine
./run lr       # launch-remote (deploy to VPS + test on VPS)
./run sy       # sync repo to VPS (no GitHub key)
./run dr       # deploy-remote
./run ss       # status
./run sm       # stream (deploy.log + compose logs)
./run sr       # stream from VPS
./run rx ...   # run any command on VPS (e.g. rx ip addr)
./run re sm    # remote stream
./run re ss    # remote status
```

**Config:** `sovereign-stack/.env` (VPS_HOST, VPS_USER, VPS_REPO_PATH, DOMAIN). Never commit.

**Full device/execution doc:** `sovereign-stack/DEPLOYMENT.md`.

**Stack control on VPS:** `sovereign-stack/prod-control.sh` (deploy | start | stop | status | test | logs | monitor).

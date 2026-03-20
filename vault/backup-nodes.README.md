# Backup nodes (org storage for log backups)

Copy `backup-nodes.example.json` to `backup-nodes.json` in this directory (same location as `org-registry.json`).

List all organisation nodes that can receive backup payloads. When `backup-dynamic-then-delete.sh` runs, it:

1. Builds a timestamped backup locally.
2. Probes each node via `ssh host df -k storage_path` to get available space.
3. **Routes the backup to the node with the largest free storage** (rsync).

Each entry:

- `host`: SSH target (e.g. `root@89.116.170.202`).
- `storage_path`: Path on that host where backups are stored (e.g. `/opt/aura/backups-incoming`).
- `label`: Optional label for Mission Control (e.g. `mesh-vps`).

The gateway exposes `GET /api/backup/nodes` (vault token) returning nodes with `avail_kb`, sorted largest-first.

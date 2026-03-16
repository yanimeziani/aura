# Nexa Autopilot System

The operating model is:

- 99% routine execution is automatic
- 1% destructive or high-impact actions stay HITL
- one control loop owns routine health and maintenance

## Control loop

Primary loop:

- [ops/autopilot/nexa_autopilot.py](/root/ops/autopilot/nexa_autopilot.py)

It performs:

1. build or verify the in-house Zig gateway
2. start the gateway if it is not healthy
3. refresh the docs bundle on interval
4. generate the ops-cast package on interval
5. optionally run backups on interval
6. write machine-readable state to `.nexa/autopilot/state.json`

## Service

Systemd unit:

- [ops/config/nexa_autopilot.service](/root/ops/config/nexa_autopilot.service)

This removes the need to manually run multiple shell scripts. The operator starts one service, then supervises state and approves only critical actions.

## HITL boundary

Keep these out of the automatic loop unless explicitly approved:

- destructive cleanup
- remote deploy cutovers
- credential rotation
- firewall or mesh policy changes
- financial or customer-impacting actions

## Commands

```bash
python3 ops/autopilot/nexa_autopilot.py run-once
python3 ops/autopilot/nexa_autopilot.py loop --interval 60
python3 ops/autopilot/nexa_autopilot.py status
```

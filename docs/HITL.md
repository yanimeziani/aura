# HITL (Human-in-the-Loop) for operators

All **medium-to-critical** actions that are **destructive** or **interface with outside the mesh** (potential big repercussions) require explicit operator confirmation before execution.

## How it works

- **Vault token** is required for all HITL-gated endpoints (operator identity).
- **Confirmation:** the client must send the header **`X-HITL-Confirm: <action_id>`** on the same request. Without it, the gateway returns **403** with a JSON body describing the required action.
- **Action IDs** are fixed strings (e.g. `delete_session`, `register_org`, `revoke_org`, `attest_org`). The dashboard or any client can show a confirmation step (“Type the action ID or click Confirm”) and then resend the request with the header.

## Gated actions

| Action ID       | Method | Endpoint                      | Reason |
|-----------------|--------|-------------------------------|--------|
| `delete_session`| DELETE | `/sync/session/{workspace_id}`| Destructive: removes synced session data. |
| `register_org`  | POST   | `/api/org/register`          | Outside mesh: writes to org registry. |
| `revoke_org`    | POST   | `/api/org/{org_id}/revoke`   | Destructive: demotes org trust; big repercussion. |
| `attest_org`    | POST   | `/api/org/{org_id}/attest`   | Trust change: sovereign override; big repercussion. |

## API

- **GET /api/hitl/actions** (Bearer vault token) — returns the list of HITL-gated actions with `id`, `method`, `path`, `reason`.
- On 403 from a gated endpoint, the response body includes `hitl_required: true`, `action`, and `message` with the exact header to send.

## Client flow

1. Operator triggers an action (e.g. “Revoke org”).
2. Client calls the endpoint **without** `X-HITL-Confirm`.
3. If gateway returns 403 with `hitl_required: true`, show a confirmation UI: “This action is destructive. Confirm by sending: X-HITL-Confirm: revoke_org”.
4. Operator confirms (e.g. button “Confirm” or type the action ID).
5. Client resends the same request **with** header `X-HITL-Confirm: <action_id>`.
6. Gateway executes and returns 200.

Agents and automation must **never** send the confirm header without explicit operator approval (e.g. via Mission Control or Pegasus).

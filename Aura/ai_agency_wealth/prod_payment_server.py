import os
import stripe
import httpx
import json
from fastapi import BackgroundTasks, FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse, PlainTextResponse
from pydantic import BaseModel
from dotenv import load_dotenv
import uvicorn

# Load environment variables
load_dotenv()

ADMIN_TOKEN = os.getenv("AURA_ADMIN_TOKEN")

STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET")
STRIPE_WEBHOOK_SECRET_THIN = os.getenv("STRIPE_WEBHOOK_SECRET_THIN")
N8N_WEBHOOK_URL = os.getenv("N8N_WEBHOOK_URL")
# Prefer our own ops webhook receiver (Zig) if configured; fallback to n8n if not.
OPS_AUTOMATION_WEBHOOK_URL = os.getenv("OPS_AUTOMATION_WEBHOOK_URL") or "http://127.0.0.1:9100/ops/stripe"

STRIPE_ENABLED = bool(STRIPE_SECRET_KEY)
if STRIPE_SECRET_KEY:
    stripe.api_key = STRIPE_SECRET_KEY
else:
    print("⚠️  STRIPE_SECRET_KEY missing: starting in NO-STRIPE mode (lead capture + non-stripe endpoints only).")

def _require_stripe_api() -> None:
    if not STRIPE_ENABLED:
        raise HTTPException(status_code=503, detail="Stripe is not configured on this server.")


def _require_stripe_webhook_secret(secret: str | None, *, name: str) -> None:
    _require_stripe_api()
    if not secret:
        raise HTTPException(status_code=503, detail=f"{name} not configured on this server.")

app = FastAPI(title="Sovereign Payment Gateway")

def _require_admin(request: Request) -> None:
    """
    Optional admin guard.
    If AURA_ADMIN_TOKEN is set, callers must send header: X-Aura-Admin-Token.
    """
    if not ADMIN_TOKEN:
        return
    token = request.headers.get("x-aura-admin-token")
    if token != ADMIN_TOKEN:
        raise HTTPException(status_code=401, detail="Unauthorized")

@app.get("/")
async def root():
    return {"status": "Sovereign API Live", "version": "1.0.0"}

# --- ACCESS & REVENUE MANAGEMENT ---
ACCESS_FILE = "access_manager.json"
LEDGER_FILE = "backpack_ledger.json"

import sqlite3

DB_PATH = "agency.db"

WEBHOOK_QUEUE_TABLE = "stripe_webhook_queue"
STRIPE_TX_TABLE = "stripe_tx"


def _db_connect():
    conn = sqlite3.connect(DB_PATH, timeout=30)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    return conn


def _ensure_webhook_queue():
    conn = _db_connect()
    try:
        conn.execute(
            f"""
            CREATE TABLE IF NOT EXISTS {WEBHOOK_QUEUE_TABLE} (
                event_id TEXT PRIMARY KEY,
                thin_mode INTEGER NOT NULL,
                event_json TEXT NOT NULL,
                received_at TEXT NOT NULL DEFAULT (datetime('now')),
                processed_at TEXT,
                status TEXT NOT NULL DEFAULT 'received',
                last_error TEXT
            )
            """
        )
        conn.execute(
            f"""
            CREATE TABLE IF NOT EXISTS {STRIPE_TX_TABLE} (
                tx_key TEXT PRIMARY KEY,
                event_id TEXT NOT NULL,
                kind TEXT NOT NULL,
                object_id TEXT,
                amount REAL,
                currency TEXT,
                email TEXT,
                occurred_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
            """
        )
        conn.commit()
    finally:
        conn.close()


_ensure_webhook_queue()


def grant_access(email: str, amount_paid: float):
    """Saves paid user to CRM and access file (Hard Paywall logic)."""
    # 1. Update legacy access file
    data = {}
    if os.path.exists(ACCESS_FILE):
        with open(ACCESS_FILE, "r") as f:
            data = json.load(f)
    data[email] = {
        "status": "paid",
        "amount": amount_paid,
        "timestamp": os.popen("date").read().strip(),
    }
    with open(ACCESS_FILE, "w") as f:
        json.dump(data, f, indent=4)

    # 2. Update Sovereign CRM
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO funnel (email, status, amount_paid)
            VALUES (?, 'PAID', ?)
            ON CONFLICT(email) DO UPDATE SET status='PAID', amount_paid=amount_paid + ?
        """,
            (email, amount_paid, amount_paid),
        )
        conn.commit()
        conn.close()
        print(f"✅ CRM Updated for {email}")
    except Exception as e:
        print(f"❌ CRM Error: {e}")


@app.get("/stats")
async def get_stats(request: Request):
    """Aggregates all revenue sources (SaaS sales + Agency income)."""
    _require_admin(request)
    saas_revenue = 0
    if os.path.exists(ACCESS_FILE):
        with open(ACCESS_FILE, "r") as f:
            data = json.load(f)
            saas_revenue = sum(user.get("amount", 0) for user in data.values())

    agency_revenue = 0
    emergency_fund = 0
    ops_fund = 0
    if os.path.exists(LEDGER_FILE):
        with open(LEDGER_FILE, "r") as f:
            ledger = json.load(f)
            agency_revenue = ledger.get("gross", 0)
            emergency_fund = ledger.get("emergency_fund", 0)
            ops_fund = ledger.get("ops_fund", 0)

    total_gross = saas_revenue + agency_revenue
    return {
        "saas_sales": saas_revenue,
        "agency_income": agency_revenue,
        "total_gross_cad": total_gross,
        "emergency_fund": emergency_fund,
        "ops_fund": ops_fund,
        "active_licenses": len(data) if os.path.exists(ACCESS_FILE) else 0,
    }


@app.get("/check-access/{email}")
async def check_access(email: str, request: Request):
    """Verifies if a user has paid for access."""
    _require_admin(request)
    return _has_access(email)


OWNER_EMAIL = os.getenv("OWNER_EMAIL", "")


def _has_access(email: str) -> dict:
    # Owner bypass — OWNER_EMAIL env var always has access.
    if OWNER_EMAIL and email.lower() == OWNER_EMAIL.lower():
        return {"access": True, "details": {"status": "owner", "amount": 0}}
    if os.path.exists(ACCESS_FILE):
        with open(ACCESS_FILE, "r") as f:
            data = json.load(f)
            if email in data:
                return {"access": True, "details": data[email]}
    return {"access": False}


PORTAL_REDIRECT_URL = os.getenv("PORTAL_REDIRECT_URL", "/dashboard")


class ValidateAccessRequest(BaseModel):
    email: str


@app.post("/validate-access")
async def validate_access(req: ValidateAccessRequest):
    """Public endpoint: check if email has access. Returns redirect URL on success."""
    result = _has_access(req.email)
    if result["access"]:
        return {"access": True, "redirect": PORTAL_REDIRECT_URL}
    return {"access": False}


class GrantAccessRequest(BaseModel):
    email: str
    reason: str = "manual_grant"
    amount: float = 0.0


@app.post("/grant-access")
async def admin_grant_access(req: GrantAccessRequest, request: Request):
    """Admin endpoint: grant access to an email without requiring Stripe payment."""
    _require_admin(request)
    grant_access(req.email, req.amount)
    return {"status": "granted", "email": req.email, "reason": req.reason}


@app.post("/lead")
async def capture_lead(request: Request):
    """Captures a new lead from the landing page."""
    data = await request.json()
    email = data.get("email")
    company = data.get("company_name", "Unknown")
    
    if not email:
        raise HTTPException(status_code=400, detail="Email is required.")

    conn = sqlite3.connect("agency.db")
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO funnel (company_name, email, status) VALUES (?, ?, ?)",
            (company, email, "NEW_LEAD")
        )
        conn.commit()
    except Exception as e:
        print(f"Error saving lead: {e}")
    finally:
        conn.close()

    return {"status": "success", "message": "Aura has captured your intent. Expect a response shortly."}

@app.post("/run")
async def run_orchestrator(request: Request):
    """Triggers the AI Agency Master Orchestrator (Protected by Paywall)."""
    _require_admin(request)
    email = request.query_params.get("email")
    if not email:
        raise HTTPException(
            status_code=401, detail="Email required for access verification."
        )

    # Check if user has paid
    access = _has_access(email)
    if not access["access"]:
        raise HTTPException(
            status_code=403,
            detail="Access denied: Infrastructure access requires valid credentials.",
        )

    print(f"🚀 USER {email} INITIATING ORCHESTRATION CYCLE...")
    import subprocess

    # Run in background to avoid blocking FastAPI
    script_dir = os.path.dirname(os.path.abspath(__file__))
    subprocess.Popen(["bash", os.path.join(script_dir, "automation_master.sh")], cwd=script_dir)
    return {"status": "started", "message": "Multi-agent orchestration system initiating..."}


@app.get("/log")
async def get_logs(request: Request):
    """Returns the latest agency execution logs."""
    # Logs contain operational details; optionally protect.
    _require_admin(request)
    log_path = "agency_metrics.log"
    if os.path.exists(log_path):
        with open(log_path, "r") as f:
            return PlainTextResponse(f.read())
    return PlainTextResponse("No logs found. Run orchestrator first.")


@app.get("/paystub")
async def get_paystub(request: Request):
    """Returns the most recent paystub PDF."""
    _require_admin(request)
    import glob
    from fastapi.responses import FileResponse

    pdfs = glob.glob("*.pdf")
    if pdfs:
        # Sort by modification time to get the newest
        latest_pdf = max(pdfs, key=os.path.getmtime)
        return FileResponse(
            latest_pdf, media_type="application/pdf", filename=latest_pdf
        )
    raise HTTPException(status_code=404, detail="No paystubs generated yet.")


@app.get("/current-offer")
async def get_current_offer():
    """Returns the dynamically spawned Micro SaaS offer."""
    if os.path.exists("current_offer.json"):
        with open("current_offer.json", "r") as f:
            return json.load(f)
    # Default offer if file doesn't exist
    return {
        "title": "AI Agency Infrastructure System",
        "description": "Deploy autonomous multi-agent systems for systematic operation and infrastructure management.",
        "price_usd": 9900,
        "features": [
            "Multi-Agent Orchestration Engine",
            "Real-time System Monitoring",
            "Automated Strategy Execution",
            "Workflow Engine Integration",
        ],
    }


class CheckoutRequest(BaseModel):
    client_name: str
    service_name: str = None
    amount_usd: int = None


@app.post("/create-checkout-session")
async def create_checkout_session(req: CheckoutRequest, request: Request):
    """Generates a live Stripe Checkout Session URL to send to clients.

    Dynamically creates a Product + Price in Stripe for this offer
    (service_name + amount) before creating the Checkout Session.
    """
    _require_admin(request)
    _require_stripe_api()
    # Use dynamic offer if amount or service_name is missing
    offer = await get_current_offer()
    service_name = req.service_name if req.service_name else offer["title"]
    amount_usd = req.amount_usd if req.amount_usd else offer["price_usd"]

    try:
        # Create a dedicated Product + Price for this checkout
        product = stripe.Product.create(
            name=service_name,
            metadata={
                "client_name": req.client_name,
            },
        )

        price = stripe.Price.create(
            product=product.id,
            unit_amount=amount_usd,
            currency="usd",
        )

        session = stripe.checkout.Session.create(
            payment_method_types=["card", "us_bank_account"],
            line_items=[
                {
                    "price": price.id,
                    "quantity": 1,
                }
            ],
            mode="payment",  # Use 'subscription' for recurring
            success_url="https://meziani.org/?payment=success&email={CUSTOMER_EMAIL}",
            cancel_url="https://meziani.org/?payment=cancelled",
            payment_method_options={
                "us_bank_account": {
                    "financial_connections": {
                        "permissions": ["payment_method", "balances"],
                    },
                },
            },
        )
        return {"checkout_url": session.url}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/checkout/fiat/{amount_cad}")
async def get_fiat_links(amount_cad: float):
    """Legacy endpoint retained for compatibility. All payments now go through Stripe Checkout."""
    return {
        "message": "Direct fiat links are disabled. Use Stripe Checkout for all payments."
    }


@app.post("/webhook/email")
async def email_webhook(request: Request):
    """Receives inbound email webhooks from Resend and triggers AI response agent."""
    # Optional shared-secret guard (recommended if exposed publicly).
    expected = os.getenv("EMAIL_WEBHOOK_TOKEN")
    if expected:
        got = request.headers.get("x-aura-email-token")
        if got != expected:
            raise HTTPException(status_code=401, detail="Unauthorized")
    payload = await request.json()
    print(f"📩 INBOUND EMAIL RECEIVED from {payload.get('from')}")

    # Trigger Node.js Responder
    try:
        async with httpx.AsyncClient() as client:
            await client.post("http://127.0.0.1:8081/process-email", json=payload)
    except Exception as e:
        print(f"❌ Failed to trigger Node Responder: {e}")

    return {"status": "received"}


@app.post("/webhook")
async def stripe_webhook(request: Request, background_tasks: BackgroundTasks):
    """Stripe webhook (SNAPSHOT payload style)."""
    _require_stripe_webhook_secret(STRIPE_WEBHOOK_SECRET, name="STRIPE_WEBHOOK_SECRET")
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")

    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, STRIPE_WEBHOOK_SECRET
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail="Invalid payload")
    except stripe.error.SignatureVerificationError as e:
        raise HTTPException(status_code=400, detail="Invalid signature")

    event_id = event.get("id")
    if not event_id:
        raise HTTPException(status_code=400, detail="Missing Stripe event id")

    enqueued = _enqueue_stripe_event(event_id=event_id, event=event, thin_mode=False)
    if enqueued:
        background_tasks.add_task(_process_enqueued_stripe_event, event_id)

    # Always ack fast; Stripe will retry on non-2xx.
    return {"status": "accepted", "enqueued": enqueued}


@app.post("/webhook/thin")
async def stripe_webhook_thin(request: Request, background_tasks: BackgroundTasks):
    """Stripe webhook (THIN payload style). Requires its own Stripe destination + secret."""
    _require_stripe_webhook_secret(STRIPE_WEBHOOK_SECRET_THIN, name="STRIPE_WEBHOOK_SECRET_THIN")

    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")

    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, STRIPE_WEBHOOK_SECRET_THIN
        )
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid payload")
    except stripe.error.SignatureVerificationError:
        raise HTTPException(status_code=400, detail="Invalid signature")

    event_id = event.get("id")
    if not event_id:
        raise HTTPException(status_code=400, detail="Missing Stripe event id")

    enqueued = _enqueue_stripe_event(event_id=event_id, event=event, thin_mode=True)
    if enqueued:
        background_tasks.add_task(_process_enqueued_stripe_event, event_id)

    return {"status": "accepted", "enqueued": enqueued}


def _enqueue_stripe_event(*, event_id: str, event: dict, thin_mode: bool) -> bool:
    event_json = json.dumps(event)
    conn = _db_connect()
    try:
        cur = conn.execute(
            f"""
            INSERT OR IGNORE INTO {WEBHOOK_QUEUE_TABLE} (event_id, thin_mode, event_json)
            VALUES (?, ?, ?)
            """,
            (event_id, 1 if thin_mode else 0, event_json),
        )
        conn.commit()
        return cur.rowcount == 1
    finally:
        conn.close()


async def _process_enqueued_stripe_event(event_id: str):
    conn = _db_connect()
    try:
        row = conn.execute(
            f"SELECT thin_mode, event_json, status FROM {WEBHOOK_QUEUE_TABLE} WHERE event_id = ?",
            (event_id,),
        ).fetchone()
        if not row:
            return
        thin_mode, event_json, status = row
        if status == "processed":
            return

        try:
            event = json.loads(event_json)
            await _handle_stripe_event(event, thin_mode=bool(thin_mode))
        except Exception as e:
            conn.execute(
                f"UPDATE {WEBHOOK_QUEUE_TABLE} SET status='error', last_error=? WHERE event_id=?",
                (str(e), event_id),
            )
            conn.commit()
            return

        conn.execute(
            f"UPDATE {WEBHOOK_QUEUE_TABLE} SET status='processed', processed_at=datetime('now'), last_error=NULL WHERE event_id=?",
            (event_id,),
        )
        conn.commit()
    finally:
        conn.close()


async def _handle_stripe_event(event, thin_mode: bool = False):
    """Handle both snapshot + thin events."""
    event_type = event.get("type")
    event_id = event.get("id")
    obj = (event.get("data") or {}).get("object") or {}

    if not event_type or not event_id:
        print("⚠️ Stripe event missing type/id; ignoring.")
        return

    # Always record that we saw the event type (useful for audit).
    print(f"📣 Stripe webhook received: {event_type} ({event_id})")
    await _trigger_ops_automation_event(event, thin_mode=thin_mode)

    # --- Payments (primary revenue path) ---
    if event_type == "checkout.session.completed":
        await _handle_checkout_session_completed(event_id, obj, thin_mode=thin_mode)
        return

    # Many Stripe integrations emit payment_intent events even when using Checkout.
    if event_type == "payment_intent.succeeded":
        await _handle_payment_intent_succeeded(event_id, obj, thin_mode=thin_mode)
        return

    # --- Refunds / reversals (negative revenue) ---
    if event_type in ("charge.refunded", "charge.refund.updated"):
        await _handle_charge_refunded(event_id, obj, thin_mode=thin_mode)
        return

    if event_type == "charge.dispute.created":
        await _record_stripe_tx(
            tx_key=f"dispute:{obj.get('id') or event_id}",
            event_id=event_id,
            kind="dispute_created",
            object_id=obj.get("id"),
            amount=None,
            currency=None,
            email=None,
        )
        return

    # --- Everything else ---
    # We intentionally do not trigger side effects for other event types by default,
    # but we still accept/record them (you selected all, so bursts are expected).
    await _record_stripe_tx(
        tx_key=f"event:{event_id}",
        event_id=event_id,
        kind=f"seen:{event_type}",
        object_id=(obj.get("id") if isinstance(obj, dict) else None),
        amount=None,
        currency=None,
        email=None,
    )


async def _trigger_ops_automation_event(event: dict, *, thin_mode: bool):
    """
    Best-effort fanout to ops automation (e.g. n8n).
    This is intentionally low-latency and deduped by Stripe event id.
    """
    if not OPS_AUTOMATION_WEBHOOK_URL:
        return

    event_id = event.get("id")
    event_type = event.get("type")
    obj = (event.get("data") or {}).get("object") or {}

    if not event_id or not event_type:
        return

    # Ensure we only dispatch once per Stripe event (even if retries occur).
    if not await _record_stripe_tx(
        tx_key=f"ops_dispatch:{event_id}",
        event_id=event_id,
        kind="ops_dispatch",
        object_id=(obj.get("id") if isinstance(obj, dict) else None),
        amount=None,
        currency=None,
        email=None,
    ):
        return

    payload = {
        "source": "stripe",
        "thin_mode": bool(thin_mode),
        "event_id": event_id,
        "event_type": event_type,
        "object_id": (obj.get("id") if isinstance(obj, dict) else None),
        "object": obj,  # includes full object for ops workflows
        "created": event.get("created"),
        "livemode": event.get("livemode"),
        "request": event.get("request"),
    }

    try:
        timeout = httpx.Timeout(connect=2.0, read=3.0, write=3.0, pool=2.0)
        async with httpx.AsyncClient(timeout=timeout) as client:
            await client.post(OPS_AUTOMATION_WEBHOOK_URL, json=payload)
        print(f"🧰 Ops automation dispatched: {event_type} ({event_id})")
    except Exception as e:
        # Record error but do not fail webhook processing.
        print(f"❌ Ops automation dispatch failed: {e}")


async def _handle_checkout_session_completed(event_id: str, session_obj: dict, thin_mode: bool):
    # Thin events may not include full object. Fetch from Stripe if needed.
    if thin_mode or not isinstance(session_obj, dict) or "amount_total" not in session_obj:
        session_id = session_obj.get("id") if isinstance(session_obj, dict) else None
        if not session_id:
            print("⚠️ checkout.session.completed missing session id; ignoring.")
            return
        session_obj = stripe.checkout.Session.retrieve(session_id)

    # Idempotency key at the business level (prevents double-counting across event types).
    session_id = session_obj.get("id")
    if not session_id:
        print("⚠️ Stripe session missing id; ignoring.")
        return

    customer_details = session_obj.get("customer_details") or {}
    customer_email = customer_details.get("email")
    amount_total = session_obj.get("amount_total")
    currency = (session_obj.get("currency") or "usd").lower()

    if amount_total is None:
        print("⚠️ Stripe session missing amount_total; ignoring.")
        return

    amount = amount_total / 100
    tx_key = f"checkout_session:{session_id}"
    if not await _record_stripe_tx(
        tx_key=tx_key,
        event_id=event_id,
        kind="checkout_session_completed",
        object_id=session_id,
        amount=amount,
        currency=currency,
        email=customer_email,
    ):
        return

    await _apply_successful_payment_side_effects(
        email=customer_email,
        amount=amount,
        source_id=session_id,
        source_kind="checkout_session",
    )


async def _handle_payment_intent_succeeded(event_id: str, pi_obj: dict, thin_mode: bool):
    if thin_mode or not isinstance(pi_obj, dict) or "amount_received" not in pi_obj:
        pi_id = pi_obj.get("id") if isinstance(pi_obj, dict) else None
        if not pi_id:
            print("⚠️ payment_intent.succeeded missing payment_intent id; ignoring.")
            return
        pi_obj = stripe.PaymentIntent.retrieve(pi_id)

    pi_id = pi_obj.get("id")
    if not pi_id:
        print("⚠️ PaymentIntent missing id; ignoring.")
        return

    amount_received = pi_obj.get("amount_received")
    currency = (pi_obj.get("currency") or "usd").lower()
    if amount_received is None:
        print("⚠️ PaymentIntent missing amount_received; ignoring.")
        return

    # Try to locate email without extra calls.
    email = None
    receipt_email = pi_obj.get("receipt_email")
    if receipt_email:
        email = receipt_email

    tx_key = f"payment_intent:{pi_id}"
    if not await _record_stripe_tx(
        tx_key=tx_key,
        event_id=event_id,
        kind="payment_intent_succeeded",
        object_id=pi_id,
        amount=(amount_received / 100),
        currency=currency,
        email=email,
    ):
        return

    await _apply_successful_payment_side_effects(
        email=email,
        amount=(amount_received / 100),
        source_id=pi_id,
        source_kind="payment_intent",
    )


async def _handle_charge_refunded(event_id: str, charge_obj: dict, thin_mode: bool):
    if thin_mode or not isinstance(charge_obj, dict) or "amount_refunded" not in charge_obj:
        charge_id = charge_obj.get("id") if isinstance(charge_obj, dict) else None
        if not charge_id:
            print("⚠️ charge.refunded missing charge id; ignoring.")
            return
        charge_obj = stripe.Charge.retrieve(charge_id)

    charge_id = charge_obj.get("id")
    if not charge_id:
        print("⚠️ Charge missing id; ignoring.")
        return

    amount_refunded = charge_obj.get("amount_refunded")
    currency = (charge_obj.get("currency") or "usd").lower()
    if amount_refunded is None or amount_refunded == 0:
        return

    # Refund idempotency: key by charge + refunded amount (Stripe may emit multiple updates).
    tx_key = f"refund_charge:{charge_id}:{amount_refunded}"
    if not await _record_stripe_tx(
        tx_key=tx_key,
        event_id=event_id,
        kind="charge_refunded",
        object_id=charge_id,
        amount=-(amount_refunded / 100),
        currency=currency,
        email=(charge_obj.get("billing_details") or {}).get("email"),
    ):
        return

    # Apply negative revenue to local ledger (do NOT revoke access automatically).
    await _apply_refund_side_effects(amount_refunded / 100)


async def _record_stripe_tx(
    *,
    tx_key: str,
    event_id: str,
    kind: str,
    object_id: str | None,
    amount: float | None,
    currency: str | None,
    email: str | None,
) -> bool:
    conn = _db_connect()
    try:
        cur = conn.execute(
            f"""
            INSERT OR IGNORE INTO {STRIPE_TX_TABLE}
                (tx_key, event_id, kind, object_id, amount, currency, email)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (tx_key, event_id, kind, object_id, amount, currency, email),
        )
        conn.commit()
        return cur.rowcount == 1
    finally:
        conn.close()


async def _apply_successful_payment_side_effects(*, email: str | None, amount: float, source_id: str, source_kind: str):
    # 60% Emergency Fund / 40% Operations Split
    emergency_cut = amount * 0.60
    ops_cut = amount * 0.40

    print(f"💰 PAYMENT SUCCEEDED: ${amount} USD ({source_kind}={source_id}) email={email or 'unknown'}")
    print(f"🛡️ EMERGENCY FUND (+60%): ${emergency_cut:.2f}")
    print(f"⚙️ OPERATIONS (+40%): ${ops_cut:.2f}")

    ledger = {"gross": 0, "emergency_fund": 0, "ops_fund": 0}
    if os.path.exists(LEDGER_FILE):
        with open(LEDGER_FILE, "r") as f:
            ledger = json.load(f)

    ledger["gross"] = ledger.get("gross", 0) + amount
    ledger["emergency_fund"] = ledger.get("emergency_fund", 0) + emergency_cut
    ledger["ops_fund"] = ledger.get("ops_fund", 0) + ops_cut

    with open(LEDGER_FILE, "w") as f:
        json.dump(ledger, f, indent=4)

    # Grant access only when we have an email.
    if email:
        grant_access(email, amount)
    else:
        print("⚠️ No email found; access grant skipped.")

    # Trigger n8n (best-effort).
    if N8N_WEBHOOK_URL:
        try:
            timeout = httpx.Timeout(connect=2.0, read=5.0, write=5.0, pool=2.0)
            async with httpx.AsyncClient(timeout=timeout) as client:
                await client.post(
                    N8N_WEBHOOK_URL,
                    json={
                        "event": "payment_success",
                        "email": email,
                        "amount": amount,
                        "source_kind": source_kind,
                        "source_id": source_id,
                    },
                )
            print(f"🔗 n8n Webhook triggered for {email or source_id}")
        except Exception as e:
            print(f"❌ Failed to trigger n8n: {e}")


async def _apply_refund_side_effects(amount: float):
    print(f"↩️ REFUND RECORDED: -${amount} USD")
    ledger = {"gross": 0, "emergency_fund": 0, "ops_fund": 0}
    if os.path.exists(LEDGER_FILE):
        with open(LEDGER_FILE, "r") as f:
            ledger = json.load(f)

    # Keep the same split logic (reduce both pools proportionally).
    ledger["gross"] = ledger.get("gross", 0) - amount
    ledger["emergency_fund"] = ledger.get("emergency_fund", 0) - (amount * 0.60)
    ledger["ops_fund"] = ledger.get("ops_fund", 0) - (amount * 0.40)

    with open(LEDGER_FILE, "w") as f:
        json.dump(ledger, f, indent=4)


if __name__ == "__main__":
    print("================================================")
    print("🚀 PRODUCTION PAYMENT SERVER STARTING 🚀")
    print("================================================")
    uvicorn.run(app, host="0.0.0.0", port=8000)

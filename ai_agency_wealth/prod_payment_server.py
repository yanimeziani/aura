import os
import stripe
import httpx
import json
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse, PlainTextResponse
from pydantic import BaseModel
from dotenv import load_dotenv
import uvicorn

# Load environment variables
load_dotenv()

# Require Live Stripe Key for Prod
STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET")
N8N_WEBHOOK_URL = os.getenv("N8N_WEBHOOK_URL")

if not STRIPE_SECRET_KEY:
    raise ValueError("CRITICAL: STRIPE_SECRET_KEY is missing. Prod requires live keys.")

stripe.api_key = STRIPE_SECRET_KEY

app = FastAPI(title="Sovereign Payment Gateway")

# --- ACCESS & REVENUE MANAGEMENT ---
ACCESS_FILE = "access_manager.json"
LEDGER_FILE = "backpack_ledger.json"

import sqlite3

DB_PATH = "agency.db"


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
async def get_stats():
    """Aggregates all revenue sources (SaaS sales + Agency income)."""
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
async def check_access(email: str):
    """Verifies if a user has paid for access."""
    if os.path.exists(ACCESS_FILE):
        with open(ACCESS_FILE, "r") as f:
            data = json.load(f)
            if email in data:
                return {"access": True, "details": data[email]}
    return {"access": False}


@app.post("/run")
async def run_orchestrator(request: Request):
    """Triggers the AI Agency Master Orchestrator (Protected by Paywall)."""
    email = request.query_params.get("email")
    if not email:
        raise HTTPException(
            status_code=401, detail="Email required for access verification."
        )

    # Check if user has paid
    access = await check_access(email)
    if not access["access"]:
        raise HTTPException(
            status_code=403,
            detail="Access denied: Infrastructure access requires valid credentials.",
        )

    print(f"🚀 USER {email} INITIATING ORCHESTRATION CYCLE...")
    import subprocess

    # Run in background to avoid blocking FastAPI
    subprocess.Popen(["bash", "automation_master.sh"], cwd=os.getcwd())
    return {"status": "started", "message": "Multi-agent orchestration system initiating..."}


@app.get("/log")
async def get_logs():
    """Returns the latest agency execution logs."""
    log_path = "agency_metrics.log"
    if os.path.exists(log_path):
        with open(log_path, "r") as f:
            return PlainTextResponse(f.read())
    return PlainTextResponse("No logs found. Run orchestrator first.")


@app.get("/paystub")
async def get_paystub():
    """Returns the most recent paystub PDF."""
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
async def create_checkout_session(req: CheckoutRequest):
    """Generates a live Stripe Checkout Session URL to send to clients.

    Dynamically creates a Product + Price in Stripe for this offer
    (service_name + amount) before creating the Checkout Session.
    """
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
async def stripe_webhook(request: Request):
    """Listens for successful payments and triggers automated fulfillment (n8n/CrewAI)."""
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

    # Handle successful payment
    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        customer_email = session["customer_details"]["email"]
        amount = session["amount_total"] / 100

        # 60% Emergency Fund / 40% Operations Split
        emergency_cut = amount * 0.60
        ops_cut = amount * 0.40

        print(f"💰 FAST CASH ACQUIRED: ${amount} USD paid by {customer_email}")
        print(f"🛡️ EMERGENCY FUND (+60%): ${emergency_cut:.2f}")
        print(f"⚙️ OPERATIONS (+40%): ${ops_cut:.2f}")

        # Update Ledger
        ledger = {"gross": 0, "emergency_fund": 0, "ops_fund": 0}
        if os.path.exists(LEDGER_FILE):
            with open(LEDGER_FILE, "r") as f:
                ledger = json.load(f)

        ledger["gross"] = ledger.get("gross", 0) + amount
        ledger["emergency_fund"] = ledger.get("emergency_fund", 0) + emergency_cut
        ledger["ops_fund"] = ledger.get("ops_fund", 0) + ops_cut

        with open(LEDGER_FILE, "w") as f:
            json.dump(ledger, f, indent=4)

        # 1. Grant Hard Paywall Access Locally
        grant_access(customer_email, amount)

        # 2. Trigger n8n webhook to start automated work (SaaS Backend)
        if N8N_WEBHOOK_URL:
            try:
                async with httpx.AsyncClient() as client:
                    await client.post(
                        N8N_WEBHOOK_URL,
                        json={
                            "event": "payment_success",
                            "email": customer_email,
                            "amount": amount,
                            "session_id": session["id"],
                        },
                    )
                print(f"🔗 n8n Webhook triggered for {customer_email}")
            except Exception as e:
                print(f"❌ Failed to trigger n8n: {e}")

    return {"status": "success"}


if __name__ == "__main__":
    print("================================================")
    print("🚀 PRODUCTION PAYMENT SERVER STARTING 🚀")
    print("================================================")
    uvicorn.run(app, host="0.0.0.0", port=8000)

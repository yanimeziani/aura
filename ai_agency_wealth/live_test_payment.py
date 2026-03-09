import os
import stripe
from dotenv import load_dotenv

load_dotenv()

stripe.api_key = os.getenv("STRIPE_SECRET_KEY")

def create_live_test():
    print("💎 GENERATING LIVE TEST PAYMENT LINK ($1.00 USD)...")
    try:
        # 1. Create a Product
        product = stripe.Product.create(
            name="Phase 1: Real-Flow Test Audit",
            description="End-to-end verification of the Meziani AI Wealth Agency.",
        )

        # 2. Create a Price ($1.00)
        price = stripe.Price.create(
            product=product.id,
            unit_amount=100, # $1.00
            currency="usd",
        )

        # 3. Create Checkout Session
        session = stripe.checkout.Session.create(
            payment_method_types=['card'],
            line_items=[{'price': price.id, 'quantity': 1}],
            mode='payment',
            success_url="https://meziani.org/?payment=success",
            cancel_url="https://meziani.org/?payment=cancelled",
        )

        print("\n================================================")
        print("✅ LIVE TEST READY!")
        print("================================================")
        print(f"URL: {session.url}")
        print("================================================")
        print("Instructions:")
        print("1. Visit the URL above and pay $1.00.")
        print("2. The system will trigger the Autopilot cycle.")
        print("3. Check /home/yani/ai_agency_wealth/autopilot_output.log to see the machine start.")
        
    except Exception as e:
        print(f"❌ Error: {e}")

if __name__ == "__main__":
    create_live_test()

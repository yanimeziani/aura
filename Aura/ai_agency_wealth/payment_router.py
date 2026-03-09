import os
import stripe
import qrcode
from io import BytesIO
from dotenv import load_dotenv

load_dotenv()

# --- CONFIGURATION ---
# In production, these should be in your .env file
STRIPE_API_KEY = os.getenv("STRIPE_SECRET_KEY", "sk_test_YOUR_STRIPE_KEY")
stripe.api_key = STRIPE_API_KEY

# Your Crypto Wallets (Self-Custody)
CRYPTO_WALLETS = {
    "USDC (ERC-20 / Base / Solana)": "0xYourSovereignWalletAddressHere",
    "Bitcoin (BTC)": "bc1YourSovereignBTCAddressHere"
}

class SovereignPaymentRouter:
    def __init__(self, client_name, service_name, amount_usd, is_subscription=True):
        self.client_name = client_name
        self.service_name = service_name
        self.amount_usd = amount_usd
        self.is_subscription = is_subscription

    def generate_stripe_link(self):
        """Generates a Stripe Payment Link for Subscription or One-Time.

        Dynamically creates a Product + Price in Stripe the first time
        this configuration is used.
        """
        try:
            if STRIPE_API_KEY == "sk_test_YOUR_STRIPE_KEY":
                return f"[Requires Real Stripe Key] -> Mock Link: https://buy.stripe.com/test_mock_{self.amount_usd}_monthly"

            # Dynamically create Product + Price for this service
            product = stripe.Product.create(
                name=self.service_name,
                metadata={
                    "client_name": self.client_name,
                    "is_subscription": str(self.is_subscription),
                },
            )

            price = stripe.Price.create(
                product=product.id,
                unit_amount=int(self.amount_usd * 100),
                currency="usd",
                recurring={"interval": "month"} if self.is_subscription else None,
            )

            payment_link = stripe.PaymentLink.create(
                line_items=[{"price": price.id, "quantity": 1}],
                payment_method_types=["card", "us_bank_account"],
            )

            return payment_link.url
        except Exception as e:
            return f"Stripe Error: {str(e)}"

    def generate_unified_invoice(self):
        """Compiles all payment routes into a single payload for the client."""
        
        print("================================================")
        print(f"💰 DIRECT MONEY INVOICE: {self.client_name} 💰")
        print("================================================")
        print(f"Service: {self.service_name}")
        print(f"Amount: ${self.amount_usd:,.2f} USD")
        print(f"Type: {'Monthly Subscription' if self.is_subscription else 'One-Time Transfer'}")
        print("================================================\n")
        
        print("ROUTE 1: FIAT SUBSCRIPTION (STRIPE)")
        print("------------------------------------------------")
        print(f"URL: {self.generate_stripe_link()}\n")
        
        print("ROUTE 2: SOVEREIGN CRYPTO (USDC / BTC)")
        print("------------------------------------------------")
        for asset, address in CRYPTO_WALLETS.items():
            print(f"{asset}:\n-> {address}")
        print()
        
        print("================================================")
        print("Status: AWAITING_FUNDS (Stripe primary)")
        print("================================================")

if __name__ == "__main__":
    # Example: You close a $2,500/mo B2B automation retainer
    router = SovereignPaymentRouter(
        client_name="Global Logistics Corp",
        service_name="Full-Auto Backoffice Infrastructure",
        amount_usd=2500.00,
        is_subscription=True
    )
    router.generate_unified_invoice()

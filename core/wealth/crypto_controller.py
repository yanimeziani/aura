import os
import json
from eth_account import Account
from web3 import Web3
import ccxt
from dotenv import load_dotenv

load_dotenv()

# --- CONFIG ---
WALLET_PATH = os.path.expanduser("/home/yani/Aura/ai_agency_wealth/local_wallet.json")

class CryptoController:
    def __init__(self):
        self.coinbase = self._init_coinbase()
        self.wallet = self._init_local_wallet()
        
        infura_key = os.getenv("INFURA_KEY")
        if infura_key:
            self.w3 = Web3(Web3.HTTPProvider(f"https://mainnet.infura.io/v3/{infura_key}"))
        else:
            print("⚠️ INFURA_KEY missing in .env. Web3 functions will be disabled.")
            self.w3 = None

    def _init_coinbase(self):
        """Initialize Coinbase Advanced Trade via CCXT."""
        api_key = os.getenv("COINBASE_API_KEY")
        api_secret = os.getenv("COINBASE_API_SECRET")
        
        if not api_key or not api_secret:
            print("⚠️ Coinbase API keys missing in .env. Coinbase functions will be disabled.")
            return None
            
        return ccxt.coinbaseadvanced({
            'apiKey': api_key,
            'secret': api_secret,
        })

    def _init_local_wallet(self):
        """Initialize wallet from ENV, then File, then Create New."""
        env_key = os.getenv("LOCAL_PRIVATE_KEY")
        if env_key:
            print("✅ Local Wallet Loaded from ENV.")
            return Account.from_key(env_key)

        if os.path.exists(WALLET_PATH):
            with open(WALLET_PATH, 'r') as f:
                data = json.load(f)
                print(f"✅ Local Wallet Loaded: {data['address']}")
                return Account.from_key(data['private_key'])
        else:
            print("🆕 Generating new local wallet...")
            new_acc = Account.create()
            wallet_data = {
                "address": new_acc.address,
                "private_key": Web3.to_hex(new_acc.key)
            }
            fd = os.open(WALLET_PATH, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(fd, 'w') as f:
                json.dump(wallet_data, f, indent=4)
            print(f"✅ New Wallet Created and Saved to {WALLET_PATH}")
            print(f"Address: {new_acc.address}")
            return new_acc

    def get_balances(self):
        """Fetch balances from both Coinbase and Local Wallet."""
        balances = {"coinbase": {}, "local": {}}

        # 1. Local wallet — ETH balance via Web3 if available
        balances["local"]["address"] = self.wallet.address
        if self.w3 and self.w3.is_connected():
            try:
                eth_wei = self.w3.eth.get_balance(self.wallet.address)
                balances["local"]["ETH"] = float(self.w3.from_wei(eth_wei, "ether"))
            except Exception as e:
                balances["local"]["ETH_error"] = str(e)
        else:
            balances["local"]["ETH"] = None  # Web3 not configured

        # 2. Coinbase Balance
        if self.coinbase:
            try:
                cb_bal = self.coinbase.fetch_balance()
                balances["coinbase"] = {k: v for k, v in cb_bal['total'].items() if v > 0}
            except Exception as e:
                balances["coinbase"] = {"error": str(e)}

        return balances

    def auto_bridge_to_local(self, asset="USDC", amount=10.0, dry_run=True):
        """Withdraw from Coinbase to Local Wallet.

        Args:
            asset:   Coin symbol (e.g. "USDC", "ETH").
            amount:  Amount to withdraw (must be > 0).
            dry_run: When True (default) only simulate — never touch real funds.
        """
        if not self.coinbase:
            return "Error: Coinbase not configured."

        if amount <= 0:
            return "Error: amount must be greater than zero."

        destination = self.wallet.address
        # Validate destination is a well-formed EIP-55 checksummed address
        if self.w3:
            if not self.w3.is_address(destination):
                return f"Error: destination address '{destination}' is not a valid Ethereum address."
            destination = self.w3.to_checksum_address(destination)

        print(f"🚀 Withdrawal: {amount} {asset} from Coinbase -> {destination}")

        if dry_run:
            return f"DRY RUN: Would withdraw {amount} {asset} to {destination} (set dry_run=False to execute)."

        try:
            result = self.coinbase.withdraw(asset, amount, destination)
            return f"Success: {result}"
        except Exception as e:
            return f"Failed: {e}"

if __name__ == "__main__":
    controller = CryptoController()
    print("\n[CRYPTO STATUS REPORT]")
    print(json.dumps(controller.get_balances(), indent=4))
    
    # Example auto-deploy logic
    print("\n[AUTO-DEPLOY ACTION]")
    print(controller.auto_bridge_to_local(amount=1.0))

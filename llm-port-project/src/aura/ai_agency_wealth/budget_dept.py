import os
import json
import logging
from lightning_manager import LightningManager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class BudgetDepartment:
    """
    Autonomous budget management integrated with the Lighting Network and Aura Vault.
    Enforces strict daily and task-based budget ceilings for multi-agent operations.
    """

    def __init__(self, budget_file="var/budget_state.json"):
        self.lightning = LightningManager()
        self.budget_file = budget_file
        self.state = self._load_budget_state()

    def _load_budget_state(self):
        if not os.path.exists(self.budget_file):
            return {
                "daily_allowance_sats": 50000,
                "spent_today_sats": 0,
                "approved_categories": ["api_usage", "server_hosting", "bounty"]
            }
        with open(self.budget_file, "r") as f:
            return json.load(f)

    def _save_budget_state(self):
        os.makedirs(os.path.dirname(self.budget_file), exist_ok=True)
        with open(self.budget_file, "w") as f:
            json.dump(self.state, f, indent=4)

    def can_afford(self, amount_sats):
        remaining = self.state["daily_allowance_sats"] - self.state["spent_today_sats"]
        return amount_sats <= remaining

    def request_funds(self, amount_sats, category, payment_request):
        """
        Request funds for an autonomous action (e.g., API payment, worker bounty).
        Automatically pays the Lightning invoice if within budget.
        """
        if category not in self.state["approved_categories"]:
            logger.error(f"Budget request denied: Category {category} not approved.")
            return False, "Category not approved."

        if not self.can_afford(amount_sats):
            logger.error(f"Budget request denied: Insufficient daily allowance.")
            return False, "Insufficient daily allowance."

        # Proceed with seamless Lightning Network transfer
        logger.info(f"Budget approved for {amount_sats} sats in {category}. Initiating LN transfer.")
        payment_result = self.lightning.pay_invoice(payment_request)

        if "payment_error" in payment_result and payment_result["payment_error"]:
            logger.error(f"Lightning payment failed: {payment_result['payment_error']}")
            return False, f"LN Error: {payment_result['payment_error']}"

        # Deduct from budget
        self.state["spent_today_sats"] += amount_sats
        self._save_budget_state()

        logger.info(f"Payment successful. Preimage: {payment_result.get('payment_preimage', 'dry_run')}")
        return True, payment_result.get('payment_preimage')

if __name__ == "__main__":
    # Test execution
    dept = BudgetDepartment()
    success, msg = dept.request_funds(1000, "api_usage", "lnbc10n1...")
    print(f"Transfer status: {success}, {msg}")

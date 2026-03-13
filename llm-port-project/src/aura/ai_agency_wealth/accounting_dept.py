import os
from fpdf import FPDF
from datetime import datetime

try:
    import qrcode
except ModuleNotFoundError as e:
    raise ModuleNotFoundError(
        "Missing dependency 'qrcode'. Install with: pip install 'qrcode[pil]'"
    ) from e

class PaystubGenerator:
    def create_paystub(self, employee_name, business_name, gross_pay, deductions, net_pay, period):
        base_dir = os.path.dirname(os.path.abspath(__file__))
        pdf = FPDF()
        pdf.add_page()
        
        # 1. Header
        pdf.set_font("helvetica", 'B', 16)
        pdf.cell(190, 10, text=f"{business_name} - OFFICIAL PAYSTUB (CAD)", new_x="LMARGIN", new_y="NEXT", align='C')
        
        # 2. Basic Info
        pdf.set_font("helvetica", size=12)
        pdf.ln(10)
        pdf.cell(190, 10, text=f"Employee: {employee_name}", new_x="LMARGIN", new_y="NEXT")
        pdf.cell(190, 10, text=f"Pay Period: {period}", new_x="LMARGIN", new_y="NEXT")
        pdf.cell(190, 10, text=f"Date of Issue: {datetime.now().strftime('%Y-%m-%d')}", new_x="LMARGIN", new_y="NEXT")
        pdf.cell(190, 10, text="Currency: CAD (Canadian Dollars)", new_x="LMARGIN", new_y="NEXT")
        
        # 3. Table
        pdf.ln(10)
        pdf.set_font("helvetica", 'B', 12)
        pdf.cell(100, 10, text="Description", border=1)
        pdf.cell(90, 10, text="Amount (CAD)", border=1, new_x="LMARGIN", new_y="NEXT")
        
        pdf.set_font("helvetica", size=12)
        pdf.cell(100, 10, text="Gross Client Revenue", border=1)
        pdf.cell(90, 10, text=f"${gross_pay:,.2f}", border=1, new_x="LMARGIN", new_y="NEXT")
        
        for desc, amt in deductions.items():
            pdf.cell(100, 10, text=f"Deduction: {desc}", border=1)
            pdf.cell(90, 10, text=f"-${amt:,.2f}", border=1, new_x="LMARGIN", new_y="NEXT")
            
        pdf.ln(5)
        pdf.set_font("helvetica", 'B', 14)
        pdf.cell(100, 10, text="TOTAL NET DEPOSIT", border=1)
        pdf.cell(90, 10, text=f"${net_pay:,.2f}", border=1, new_x="LMARGIN", new_y="NEXT")
        
        # 4. QR Code for Wealthsimple Cash (Interac e-Transfer)
        ws_handle = "yanimeziani"
        # Standard Interac e-Transfer email for Wealthsimple handles
        deposit_url = f"mailto:{ws_handle}@wealthsimple.me?subject=Agency%20Net%20Deposit&body=Transferring%20${net_pay:,.2f}%20CAD%20to%20Wealthsimple%20Cash."
        
        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(deposit_url)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        qr_path = os.path.join(base_dir, "deposit_qr.png")
        img.save(qr_path)
        
        pdf.ln(15)
        pdf.set_font("helvetica", 'I', 10)
        pdf.cell(190, 10, text=f"Scan to Send CAD to {ws_handle}@wealthsimple.me (Auto-Deposit):", new_x="LMARGIN", new_y="NEXT", align='C')
        pdf.image(qr_path, x=75, y=pdf.get_y(), w=50)
        
        pdf.ln(60)
        pdf.set_font("helvetica", size=8)
        pdf.cell(190, 10, text=f"Recipient: {ws_handle} | Recurring Client Revenue Stream", new_x="LMARGIN", new_y="NEXT", align='C')
        
        filename = f"paystub_{datetime.now().strftime('%Y%m%d')}.pdf"
        filepath = os.path.join(base_dir, filename)
        pdf.output(filepath)
        return filepath

if __name__ == "__main__":
    generator = PaystubGenerator()
    # Updated to reflect real client revenue in CAD and private health allocation
    path = generator.create_paystub(
        employee_name="Yani Meziani",
        business_name="AI Wealth Agency Corp",
        gross_pay=12500.00, # Increased for real client scale
        deductions={
            "Tax Withholding": 1800.00, 
            "Operational Credits": 1000.00,
            "Private Health (HSA) Allocation": 500.00
        },
        net_pay=9200.00, # Net pay updated after health deduction
        period="March 2026 (Full Private Health Mode)"
    )
    print(f"✅ Paystub (CAD) generated for Wealthsimple: {path}")

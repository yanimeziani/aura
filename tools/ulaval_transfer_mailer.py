#!/usr/bin/env python3
import os
import sys
import argparse
from pathlib import Path

# Add tools directory to path
ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.append(str(ROOT_DIR))
import resend_outreach

def send_ulaval_transfer_proposal(recipient_email, recipient_name):
    print(f"🚀 Initializing Official Ulaval Transfer Protocol...")
    
    api_key = os.environ.get("RESEND_API_KEY")
    if not api_key:
        print("❌ RESEND_API_KEY not set. Cannot send official transfer email.")
        sys.exit(1)
        
    from_email = "Yani Meziani <yani@meziani.ai>"
    subject = "PROPOSITION OFFICIELLE : Transfert du Protocole Souverain Versailles (Université Laval / CERVO)"
    
    html_template = f"""
    <div style="font-family: Arial, sans-serif; max-width: 650px; margin: auto; padding: 30px; border: 1px solid #dcdcdc; border-top: 5px solid #b30000;">
        <h2 style="color: #333; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;">Meziani AI Digital Studio</h2>
        <p>Bonjour <strong>{recipient_name}</strong>,</p>
        
        <p>Je vous contacte formellement pour officialiser le transfert de l'architecture logicielle <strong>"Versailles Sovereign Protocol"</strong> vers l'écosystème de recherche de l'Université Laval.</p>
        
        <p>Conçu pour garantir une souveraineté numérique absolue et une sécurité biologique mentale (charge cognitive nulle), ce protocole est prêt pour un audit institutionnel et une validation clinique par les experts du centre CERVO.</p>
        
        <h3 style="color: #444; border-bottom: 1px solid #eee; padding-bottom: 5px;">Axes de Collaboration Proposés :</h3>
        <ul style="color: #555;">
            <li><strong>Audit Technique :</strong> Évaluation de notre moteur de réseau haute performance (implémenté en Zig).</li>
            <li><strong>Validation Clinique (CERVO) :</strong> Tests des seuils de charge cognitive via notre "Bouclier Versailles".</li>
            <li><strong>Déploiement Pilote :</strong> Création d'un micro-réseau académique 100% privé et décentralisé.</li>
        </ul>
        
        <p>Vous trouverez les spécifications techniques et l'accord de transfert préliminaire dans notre dépôt de recherche. Je suis à votre entière disposition pour planifier une rencontre formelle afin de signer l'accord de transfert et lancer la phase pilote.</p>
        
        <br/>
        <p>Dans l'attente de votre retour, je vous prie d'agréer, {recipient_name}, l'expression de mes salutations distinguées.</p>
        
        <div style="margin-top: 20px; padding-top: 15px; border-top: 1px solid #eee; font-size: 0.9em; color: #666;">
            <strong>Yani Meziani</strong><br/>
            Fondateur & Architecte Logiciel Principal<br/>
            Meziani AI Digital Studio<br/>
            <a href="https://meziani.ai" style="color: #b30000; text-decoration: none;">meziani.ai</a> | yamez6@ulaval.ca
        </div>
    </div>
    """
    
    print(f"📤 Sending Official Transfer Proposal to {recipient_email}...")
    res = resend_outreach.send_email(api_key, from_email, recipient_email, subject, html_template)
    
    if res:
        print(f"✅ Transfer proposal successfully transmitted to {recipient_email}.")
    else:
        print(f"❌ Transfer transmission failed.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ulaval Official Transfer Mailer")
    parser.add_argument("--to", default="yamez6@ulaval.ca", help="Recipient email address (Defaults to your Ulaval alias for testing)")
    parser.add_argument("--name", default="Direction de la Recherche", help="Recipient name or title")
    
    args = parser.parse_args()
    send_ulaval_transfer_proposal(args.to, args.name)

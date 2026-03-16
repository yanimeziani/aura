import os

def create_export(filename, files, dirs):
    print(f"Creating {filename}...")
    with open(filename, "w", encoding="utf-8") as outfile:
        outfile.write(f"# {filename.replace('.txt', '').replace('_', ' ')}\n\n")
        
        for f in files:
            if os.path.exists(f):
                outfile.write(f"## FILE: {f}\n\n")
                with open(f, "r", encoding="utf-8", errors="replace") as infile:
                    outfile.write(infile.read())
                outfile.write("\n\n---\n\n")
        
        for d in dirs:
            if not os.path.exists(d): continue
            for root, _, filenames in os.walk(d):
                for fname in filenames:
                    if fname.endswith(('.md', '.txt', '.sql', '.sh', '.zig', '.json')):
                        if any(x in root for x in ['node_modules', '.zig-cache', '.next', 'vendor']): continue
                        fpath = os.path.join(root, fname)
                        outfile.write(f"## FILE: {fpath}\n\n")
                        with open(fpath, "r", encoding="utf-8", errors="replace") as infile:
                            outfile.write(infile.read())
                        outfile.write("\n\n---\n\n")

# 1. Vision & Manifesto
create_export("Aura_Vision_Manifesto.txt", 
    ["README.md", "GEMINI.md", "docs/PRD.md", "docs/AURAMANIFESTO.md", "docs/Notebook.lm.md", "research/aura-manifesto/main.tex"], 
    [])

# 2. Technical Architecture
create_export("Aura_Technical_Architecture.txt", 
    ["GEMINI.md", "docs/SYSTEM_CAPABILITIES.md", "docs/PROJECT_SOURCE_TRUTH.md"], 
    ["core/cerberus/specs", "apps/web/supabase/migrations"])

# 3. Agents (Career-Twin & SDR)
create_export("Aura_Agents_Product.txt", 
    ["docs/README_AGENTS.md"], 
    ["core/cerberus/configs", "core/cerberus/runtime/cerberus-core/prompts", "core/cerberus/scripts"])

# 4. Ops (Deploy & Recovery)
create_export("Aura_Ops_Runbook.txt", 
    ["docs/DEPLOYMENT_GUIDE.md", "docs/VPS_DEPLOYMENT.md", "docs/VPS_READY.md", "apps/mobile/RELEASE_APK.md"], 
    ["ops/scripts"])


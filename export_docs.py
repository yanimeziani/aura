import os

output_file = "nexa-docs-export.md"
include_dirs = [
    "docs",
    "core/cerberus/specs",
    "core/cerberus/runbooks",
    "core/vault",
    "apps/web",
    "apps/mobile",
    "apps/aura-landing-next",
    "research"
]
include_root_files = ["README.md", "GEMINI.md", "SECURITY.md", "CONTRIBUTING.md"]

def is_valid_md(filepath):
    # Ignore node_modules, vendored code, zig-cache, etc.
    if "node_modules" in filepath or "vendor" in filepath or ".zig-cache" in filepath or ".next" in filepath or ".gradle" in filepath:
        return False
    return filepath.endswith(".md")

with open(output_file, "w", encoding="utf-8") as outfile:
    outfile.write("# Nexa Monorepo: Full Documentation Export\n\n")
    outfile.write("This document contains the complete exported documentation for the Nexa project, suitable for NotebookLM ingestion and audio generation.\n\n")
    outfile.write("---\n\n")
    
    # Process root files
    for root_file in include_root_files:
        if os.path.exists(root_file):
            with open(root_file, "r", encoding="utf-8", errors="replace") as infile:
                outfile.write(f"## File: {root_file}\n\n")
                outfile.write(infile.read())
                outfile.write("\n\n---\n\n")

    # Process directories
    for d in include_dirs:
        if not os.path.exists(d):
            continue
        for root, dirs, files in os.walk(d):
            for file in files:
                filepath = os.path.join(root, file)
                if is_valid_md(filepath):
                    with open(filepath, "r", encoding="utf-8", errors="replace") as infile:
                        outfile.write(f"## File: {filepath}\n\n")
                        outfile.write(infile.read())
                        outfile.write("\n\n---\n\n")

print(f"Successfully generated {output_file}")

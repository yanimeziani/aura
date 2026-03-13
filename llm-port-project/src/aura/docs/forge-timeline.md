# Forge timeline — micro tasks, agentic, overnight

Plan en micro-tâches pour un agent : exécution séquentielle, vérification par tâche, usage de tokens maîtrisé. Conçu pour tourner overnight (une tâche après l’autre ; en échec : stop + rapport).

## Safe operations only (no destructive / irreversible actions)

- **Approved:** All work in this timeline is approved **provided** no operation is destructive or irreversible on this system or any device.
- **Forbidden:** Wipe, format, drop database, overwrite production data without backup, `rm -rf` on user or shared data paths, irreversible key rotation, or any action that cannot be undone.
- **Required:** Use **safe methods** only: create new files, write to temp then atomic move, append-only logs, read-only checks, build in `zig-out/` or `out/`, checkpoint/state in `vault/` without deleting existing state. If a task would require a destructive step, use a safe alternative (e.g. write to `*.new` then user can swap) or skip and report.

## Conventions

- **ID** : `F` + numéro (ex. F01). Unicité par tâche.
- **Verify** : commande ou critère pour considérer la tâche réussie. À lancer après l’action.
- **Tokens** : `L` = léger (peu de contexte), `M` = moyen, `H` = lourd. Cible = rester L/M.
- **Depends** : IDs des tâches à avoir réussies avant celle-ci.
- **Overnight** : exécuter dans l’ordre ; à chaque tâche : faire l’action → lancer Verify → si échec, écrire `FORGE_FAILED=<ID>` et arrêter ; si succès, écrire `FORGE_DONE=<ID>` (optionnel) et continuer.

---

## Phase 0 — Bootstrap (répo, Zig lock)

| ID   | Task | Verify | Tokens | Depends |
|------|------|--------|--------|--------|
| F01  | Vérifier `.zig-version` = 0.15.2 et présence de `docs/ZIG_VERSION.md`. | `cat .zig-version` et `test -f docs/ZIG_VERSION.md` | L | — |
| F02  | Vérifier que tous les `build.zig.zon` ont `minimum_zig_version = "0.15.2"`. | `grep -r minimum_zig_version aura-edge aura-tailscale aura-mcp tui --include='*.zon' \| grep -v 0.15.2 \|\| true` doit être vide. | L | — |
| F03  | Build des 4 projets Zig (aura-edge, aura-tailscale, aura-mcp, tui). | `cd aura-edge && zig build && cd ../aura-tailscale && zig build && cd ../aura-mcp && zig build && cd ../tui && zig build` | M | — |

---

## Phase 1 — Ziggy compiler (squelette)

| ID   | Task | Verify | Tokens | Depends |
|------|------|--------|--------|--------|
| F04  | Créer `ziggy-compiler/build.zig` et `build.zig.zon` (Zig 0.15.2), exe `ziggy` ou `ziggyc`. | `cd ziggy-compiler && zig build` | L | F03 |
| F05  | Ajouter `ziggy-compiler/src/main.zig` : CLI qui lit un argument (fichier ou `--version`), affiche un message, exit 0. | `./zig-out/bin/ziggyc --version` ou `./zig-out/bin/ziggyc 2>&1 \| head -1` | L | F04 |
| F06  | Émettre une ligne de log structurée (ex. `level=progress phase=start name=lex`) sur stderr dans `main.zig`. | `./ziggyc foo.zig 2>&1 \| grep -q 'phase='` | L | F05 |
| F07  | Créer `ziggy-compiler/src/lex.zig` : module vide exportant `fn tokenize(allocator, []const u8) void` (stub). Appeler depuis main.zig et émettre `phase=lex` avant/après. | `zig build` et `./ziggyc src/main.zig 2>&1 \| grep lex` | M | F06 |
| F08  | Ajouter `ziggy-compiler/src/alarms.zig` : type `AlarmCategory` enum (security, performance, syntax, architecture) et `fn emitAlarm(writer, category, msg)` stub (écrit une ligne sur stderr). | `zig build` ; pas de test auto requis. | L | F06 |
| F09  | Créer `ziggy-compiler/src/artifacts.zig` : `fn ensureOutDir(allocator, out_root) !void` qui crée `out_root/bin`, `out_root/lib`, `out_root/lint`, `out_root/reports`. | Test unitaire dans le fichier ou `zig build test`. | M | F04 |

---

## Phase 2 — aura-mcp (outil + robustesse)

| ID   | Task | Verify | Tokens | Depends |
|------|------|--------|--------|--------|
| F10  | S’assurer que `aura-mcp` build et que les tests passent. | `cd aura-mcp && zig build && zig build test` | L | F03 |
| F11  | Ajouter un outil MCP `ping` dans `aura-mcp/src/main.zig` : `tools/call` avec name `ping` retourne `{"content":[{"type":"text","text":"pong"}]}`. | Envoyer une requête JSON-RPC `tools/call` avec name=ping et vérifier réponse contient "pong". | M | F10 |
| F12  | Documenter dans `docs/sovereign-mcp.md` que `aura-mcp` expose `read_file`, `list_dir`, `ping`. | `grep -q ping docs/sovereign-mcp.md` | L | F11 |

---

## Phase 3 — Lint report format (spec + stub)

| ID   | Task | Verify | Tokens | Depends |
|------|------|--------|--------|--------|
| F13  | Ajouter dans `docs/ziggy-compiler.md` une sous-section "Lint report artifact format" : une ligne par finding (JSON Lines ou key=value), champs `file`, `line`, `col`, `severity`, `rule_id`, `message`. | `grep -q 'Lint report artifact format' docs/ziggy-compiler.md` | L | — |
| F14  | Dans `ziggy-compiler`, ajouter `src/lint.zig` : struct `LintReport` avec `addFinding(file, line, col, severity, rule_id, message)` et `writeToFile(path)` écrivant un fichier (vide ou une ligne exemple). Appel depuis main si `--lint-only`. | `zig build` et `./ziggyc --lint-only 2>&1` ou écriture dans `out/lint/report.jsonl`. | M | F07, F09 |

---

## Phase 4 — aura-tailscale (premier pas WireGuard)

| ID   | Task | Verify | Tokens | Depends |
|------|------|--------|--------|--------|
| F15  | Créer `aura-tailscale/src/wireguard.zig` : constantes uniquement (CONSTRUCTION, IDENTIFIER, KEY_SIZE, MAC_SIZE) déplacées depuis `root.zig`. | `zig build` dans aura-tailscale. | L | F03 |
| F16  | Ajouter dans `aura-tailscale/src/wireguard.zig` une fonction `fn hash(allocator, input: []const u8) ![]const u8` utilisant `std.crypto.hash.blake2.Blake2s256`. | Test unitaire `hash("test")` retourne 32 bytes. | M | F15 |
| F17  | Documenter dans `aura-tailscale/AGENTS.md` que `wireguard.zig` contient les constantes et le hash BLAKE2s pour le handshake. | `grep -q wireguard.zig aura-tailscale/AGENTS.md` | L | F16 |

---

## Phase 5 — Forge runner (overnight)

| ID   | Task | Verify | Tokens | Depends |
|------|------|--------|--------|--------|
| F18  | Créer `bin/forge-run.sh` : script qui lit `docs/forge-timeline.md`, parse les IDs F01..F18, et pour chaque ID exécute la tâche (mapping ID → commande ou "manual") puis la vérification ; en échec écrit `FORGE_FAILED=<ID>` dans le repo et exit 1. | Exécuter `./bin/forge-run.sh` et vérifier qu’il avance au moins jusqu’à F03. | H | F01–F17 |
| F19  | Ajouter dans `docs/forge-timeline.md` une section "Checkpoint" : nom du fichier d’état (ex. `vault/forge_checkpoint.txt`) contenant la dernière tâche réussie. `forge-run.sh` met à jour ce fichier après chaque succès. | Après run réussi, `cat vault/forge_checkpoint.txt` contient un ID. | L | F18 |

---

## Ordre d’exécution recommandé (overnight)

```
F01 → F02 → F03 → F04 → F05 → F06 → F07 → F08 → F09 → F10 → F11 → F12 → F13 → F14 → F15 → F16 → F17 → F18 → F19
```

- **Token usage** : Traiter une tâche à la fois ; ne charger que la section du doc + les fichiers concernés (1–2 fichiers par tâche quand c’est du code).
- **Run overnight** : Lancer `bin/forge-run.sh` ; en cas d’échec, le matin lire `FORGE_FAILED` ou `vault/forge_checkpoint.txt` et reprendre à la tâche suivante ou corriger la tâche en échec.

---

## Checkpoint (état)

- **Fichier** : `vault/forge_checkpoint.txt` — une ligne : dernier ID réussi (ex. `F07`).
- **En échec** : `FORGE_FAILED=<ID>` (variable d’environnement ou fichier `vault/forge_failed.txt`) pour arrêt et rapport.

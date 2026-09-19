#!/usr/bin/env python3
"""Inspect a chip repository and add a fact-based Agent-Native documentation layer.

The script is deliberately conservative: it never moves functional files and never
overwrites an existing file unless --update-agents is explicitly requested. Generated
content is deterministic and based only on repository evidence.
"""

from __future__ import print_function

import argparse
import json
import os
import re
from pathlib import Path


IGNORE_DIRS = {
    ".git", ".hg", ".svn", "__pycache__", ".pytest_cache", ".mypy_cache",
    "node_modules", ".venv", "venv", "runs", "build", "out", "output",
    "simv.daidir", "csrc", "DVEfiles", "verdiLog", "work", "INCA_libs",
}
TEXT_SUFFIXES = {
    ".md", ".rst", ".txt", ".yaml", ".yml", ".json", ".toml", ".ini",
    ".mk", ".tcl", ".do", ".f", ".flist", ".py", ".sh", ".bash",
    ".sv", ".svh", ".v", ".vh", ".vhd", ".vhdl", ".c", ".cc", ".cpp",
    ".h", ".hpp", ".scala", ".sc", ".bsv", ".sby", ".sdc", ".upf",
    ".cpf", ".rdl", ".xml", ".cfg", ".conf",
}
HDL_SUFFIXES = {".sv", ".svh", ".v", ".vh", ".vhd", ".vhdl", ".bsv"}
READMES = {"README", "README.md", "README.rst", "README.txt", "readme.md"}
GENERATED_BEGIN = "<!-- organize-chip-project:generated-begin -->"
GENERATED_END = "<!-- organize-chip-project:generated-end -->"
GENERATED_FILE = "<!-- organize-chip-project:generated-file -->"


def rel(root, path):
    return path.relative_to(root).as_posix()


def is_generator_owned(path):
    text = read_text(path)
    return text.startswith(GENERATED_FILE) or '"generator": "organize-chip-project"' in text


def is_generator_managed_agents(path):
    return GENERATED_BEGIN in read_text(path) and GENERATED_END in read_text(path)


def iter_files(root):
    for base, dirs, files in os.walk(str(root), followlinks=False):
        kept = []
        for d in dirs:
            candidate = Path(base) / d
            candidate_rel = rel(root, candidate)
            if d in IGNORE_DIRS or (d.startswith(".") and d not in {".github", ".gitlab"}):
                continue
            if candidate_rel == "docs/ai-native":
                continue
            kept.append(d)
        dirs[:] = sorted(kept)
        for name in sorted(files):
            path = Path(base) / name
            try:
                relative = rel(root, path)
                if relative == "AGENTS.md" and is_generator_managed_agents(path):
                    continue
                if relative == "docs/exec-plans/active/execution-frontier.md" and is_generator_owned(path):
                    continue
                if path.is_symlink() or path.stat().st_size <= 2 * 1024 * 1024:
                    yield path
            except OSError:
                continue


def read_text(path):
    try:
        if path.stat().st_size > 2 * 1024 * 1024:
            return ""
        return path.read_text(encoding="utf-8", errors="replace")
    except (OSError, UnicodeError):
        return ""


def classify(path):
    p = path.as_posix().lower()
    name = path.name.lower()
    if "generated" in name or "/generated/" in p:
        return "generated-source / output boundary"
    if name in ("readme", "readme.md", "readme.rst", "readme.txt"):
        return "project guidance / source of truth"
    if name == "agents.md":
        return "agent instructions"
    if p.startswith("docs/") and path.suffix.lower() in {".md", ".rst", ".txt"}:
        return "design / verification documentation"
    if "test" in p or "/tb" in p or p.startswith("tb") or "uvm" in p or "cocotb" in p:
        return "verification source"
    if any(x in p for x in ("constraint", ".sdc", "upf", "cpf")):
        return "constraints / power intent"
    if p.startswith("ip/") or any(x in p for x in ("vendor", "third_party", "third-party", "/ip/", "pdk")):
        return "vendor / external boundary"
    if path.suffix.lower() in HDL_SUFFIXES:
        return "RTL / HDL source"
    if name in {"bender.yml", "bender.yaml", "fusesoc.conf", "core.yml", "core.yaml"}:
        return "project manifest"
    if name in ("makefile", "justfile") or path.suffix.lower() in {".mk", ".tcl", ".do", ".f", ".flist"}:
        return "build / EDA flow input"
    if path.suffix.lower() in {".py", ".sh", ".bash"}:
        return "tool / automation script"
    if name in {"eda.yaml", "eda.yml", "fusesoc.conf", "project.yml", "project.yaml"}:
        return "project manifest"
    return "project artifact"


def extract_targets(text, style):
    targets = []
    if style == "make":
        pattern = re.compile(r"^([A-Za-z0-9_.@%/-]+)\s*:(?![=])", re.M)
    else:
        pattern = re.compile(r"^([A-Za-z0-9_.@%/-]+)\s*:", re.M)
    for value in pattern.findall(text):
        if value not in targets and not value.startswith("."):
            targets.append(value)
    return targets[:40]


def extract_commands(text):
    commands = []
    patterns = [
        r"^\s*(?:\$\s*)?(?:make|gmake|just|python(?:3)?|pytest|vcs|verdi|dc_shell|fc_shell|pt_shell|icc2_shell|icc_shell|spyglass|vcf|tmax|dft_shell)\b[^\n`]*",
        r"^\s*(?:run|build|test|lint|sim|formal|synth|regress|clean)\s*[:=].*",
    ]
    for pattern in patterns:
        for match in re.finditer(pattern, text, re.M | re.I):
            command = re.sub(r"\s+", " ", match.group(0).strip())
            if command not in commands:
                commands.append(command)
    return commands[:60]


def extract_purpose(text):
    """Return the first prose paragraph from a README without treating headings as prose."""
    paragraph = []
    for raw in text.splitlines()[:160]:
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith("<!--") or line.startswith("!"):
            if paragraph:
                break
            continue
        if line.startswith(("```", "- ", "* ", "> ", "[")):
            continue
        line = re.sub(r"`([^`]*)`", r"\1", line)
        line = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", line)
        paragraph.append(line)
        if len(" ".join(paragraph)) >= 400:
            break
    summary = " ".join(paragraph)
    return summary[:450].rstrip()


def inspect(root):
    files = list(iter_files(root))
    rel_files = [rel(root, p) for p in files]
    texts = {}
    for path in files:
        if path.suffix.lower() in TEXT_SUFFIXES or path.name in {"Makefile", "Justfile", "Dockerfile"}:
            texts[rel(root, path)] = read_text(path)

    top_dirs = sorted({p.split("/", 1)[0] for p in rel_files if "/" in p})
    top_files = sorted({p for p in rel_files if "/" not in p})
    evidence = []
    purpose = ""
    for name in sorted(texts):
        base = name.rsplit("/", 1)[-1]
        if base in READMES or base in {"Makefile", "Justfile", "eda.yaml", "eda.yml", "project.yml", "project.yaml"} or name.startswith(".github/"):
            evidence.append(name)
        if not purpose and base in READMES:
            purpose = extract_purpose(texts[name])

    targets = {}
    commands = []
    for name, text in texts.items():
        base = name.rsplit("/", 1)[-1].lower()
        if base == "makefile" or base.endswith(".mk"):
            found = extract_targets(text, "make")
            if found:
                targets[name] = found
        elif base == "justfile":
            found = extract_targets(text, "just")
            if found:
                targets[name] = found
        if base in {"readme", "readme.md", "readme.rst"} or name.startswith(".github/"):
            commands.extend(extract_commands(text))
    for path, values in targets.items():
        runner = "just" if path.rsplit("/", 1)[-1].lower() == "justfile" else "make"
        prefix = "-f %s " % path if "/" in path else ""
        commands.extend("%s %s%s" % (runner, prefix, value) for value in values)
    commands = list(dict.fromkeys(commands))[:80]

    modules = []
    for name, text in texts.items():
        if Path(name).suffix.lower() not in HDL_SUFFIXES:
            continue
        for match in re.finditer(r"\bmodule\s+([A-Za-z_][A-Za-z0-9_$]*)", text):
            item = {"name": match.group(1), "file": name}
            if item not in modules:
                modules.append(item)
    module_names = {m["name"] for m in modules}
    probable_tops = [m["name"] for m in modules if not re.match(r"(?i)^(tb_|test_|testbench|.*_tb$)", m["name"])]
    probable_tops = list(dict.fromkeys(probable_tops))[:30]

    role_paths = {}
    for name in rel_files:
        role = classify(Path(name))
        role_paths.setdefault(role, []).append(name)
    for role in role_paths:
        role_paths[role] = role_paths[role][:80]

    eda = {}
    for name in ("eda.yaml", "eda.yml"):
        if name in texts:
            for key in ("name", "top", "rtl", "tb", "simulator", "pdk"):
                match = re.search(r"^[ \t]*%s[ \t]*:[ \t]*(.+?)\s*$" % re.escape(key), texts[name], re.M)
                if match:
                    eda[key] = match.group(1).strip().strip("'\"")
            eda["file"] = name
            break

    return {
        "generator": "organize-chip-project",
        "root": ".",
        "file_count": len(rel_files),
        "top_directories": top_dirs[:80],
        "top_files": top_files[:80],
        "evidence_files": evidence[:80],
        "purpose": purpose,
        "role_paths": role_paths,
        "flow_targets": targets,
        "commands": commands,
        "hdl_modules": modules[:200],
        "probable_tops": probable_tops,
        "eda_config": eda,
    }


def bullet_paths(items, limit=12):
    if not items:
        return ["- None discovered; mark the missing source explicitly before changing code."]
    return ["- `%s`" % x for x in items[:limit]]


def generated_block(data):
    roles = data["role_paths"]
    lines = [GENERATED_BEGIN, "", "## Purpose and current state", ""]
    lines.append("This section is generated from repository evidence. Re-run `generate_agent_native.py` after structural or flow changes.")
    lines.append("")
    lines.append("")
    lines.append("- Repository root: `.`")
    lines.append("- Inventory: **%d** files in the bounded source tree." % data["file_count"])
    if data["purpose"]:
        lines.append("- Project purpose (from README; confirm current status separately): %s" % data["purpose"])
    else:
        lines.append("- Project purpose: not stated in a machine-verifiable source; read the evidence below before making design assumptions.")
    if data["eda_config"].get("top"):
        lines.append("- Canonical EDA top (from manifest): `%s`." % data["eda_config"]["top"])
    elif data["probable_tops"]:
        lines.append("- Probable HDL tops (heuristic; verify against the canonical flow): `%s`." % "`, `".join(data["probable_tops"][:12]))
    else:
        lines.append("- HDL tops: not discovered by the lightweight scan; use the canonical manifest/filelist.")
    if data["eda_config"]:
        lines.append("- EDA manifest: `%s` (%s)." % (data["eda_config"].get("file"), ", ".join("%s=%s" % (k, v) for k, v in data["eda_config"].items() if k != "file")))
    else:
        lines.append("- No root `eda.yaml`/`eda.yml` was discovered; do not invent Synopsys commands.")
    lines.append("")
    lines.append("## Sources of truth")
    lines.append("")
    for path in data["evidence_files"][:12]:
        lines.append("- `%s` — repository guidance, manifest, CI, or canonical flow evidence." % path)
    if not data["evidence_files"]:
        lines.append("- Not discovered. Establish the requirement/specification, canonical manifest, and known-good commands before editing.")
    lines.append("")
    lines.append("## Important paths")
    lines.append("")
    for role in ("project guidance / source of truth", "design / verification documentation", "RTL / HDL source", "verification source", "build / EDA flow input", "project manifest", "constraints / power intent", "tool / automation script", "generated-source / output boundary", "vendor / external boundary"):
        if role in roles:
            lines.append("- **%s:** %s" % (role, ", ".join("`%s`" % p for p in roles[role][:10])))
    lines.append("")
    lines.append("## Before work")
    lines.append("")
    lines.append("- Read `AGENTS.md`, then the relevant source-of-truth files above, `docs/ai-native/design-verification-index.md`, and `docs/exec-plans/active/execution-frontier.md`.")
    lines.append("- Run `git status` and retain any pre-existing user changes. Confirm source ordering and configuration before moving or editing functional files.")
    lines.append("")
    lines.append("## Setup and canonical commands")
    lines.append("")
    if data["commands"]:
        lines.extend("- `%s`" % c for c in data["commands"][:20])
    else:
        lines.append("- No executable command was safely inferred. Inspect flow files and record a known-good command before running tools.")
    if data["flow_targets"]:
        targets = []
        for path, values in sorted(data["flow_targets"].items()):
            targets.append("`%s`: %s" % (path, ", ".join("`%s`" % value for value in values[:12])))
        lines.append("- Declared targets: %s" % "; ".join(targets[:4]))
    lines.append("")
    lines.append("## Modification policy")
    lines.append("")
    lines.append("- Preserve RTL, DV, manifests, filelists, constraints, generated-source inputs, vendor/IP, and signoff artifacts unless the migration ledger names the change.")
    lines.append("- Treat generated, vendor, PDK, encrypted, licensed, and run-output paths as protected until their provenance and regeneration flow are known.")
    lines.append("- Change generator inputs rather than generated RTL or reports; use the repository's established regeneration flow.")
    lines.append("")
    lines.append("## Debug and review invariants")
    lines.append("")
    lines.append("- Reproduce the failure with the same configuration, testbench, parameters, seed, and tool before changing code.")
    lines.append("- Do not weaken assertions, tests, scoreboards, lint waivers, or constraints merely to make a run pass.")
    lines.append("")
    lines.append("## Definition of done")
    lines.append("")
    lines.append("- Run the relevant established checks, or record the exact unavailable environment/baseline failure.")
    lines.append("- Update `docs/exec-plans/active/execution-frontier.md` with the exact command, result, log path, and next action after every non-trivial task.")
    lines.append("")
    lines.append(GENERATED_END)
    return "\n".join(lines)


def render_repository_map(data):
    lines = [GENERATED_FILE, "# Repository map", "", "Generated from a bounded scan; verify any heuristic before relying on it.", "", "## Top-level layout", ""]
    lines.extend("- `%s/`" % x for x in data["top_directories"])
    lines.extend("- `%s`" % x for x in data["top_files"])
    lines += ["", "## HDL inventory", ""]
    if data["hdl_modules"]:
        lines.extend("- `%s` — `%s`" % (m["name"], m["file"]) for m in data["hdl_modules"][:80])
    else:
        lines.append("No SystemVerilog/Verilog/VHDL module declarations were found by the lightweight scan.")
    lines += ["", "## Role index", ""]
    for role in sorted(data["role_paths"]):
        lines.append("### %s" % role)
        lines.append("")
        lines.extend(bullet_paths(data["role_paths"][role], 25))
        lines.append("")
    return "\n".join(lines)


def render_commands(data):
    lines = [GENERATED_FILE, "# Command index", "", "Only commands evidenced by repository text are listed. Validate environment and source revision before execution.", "", "## Build/flow targets", ""]
    if data["flow_targets"]:
        for path, targets in sorted(data["flow_targets"].items()):
            lines.append("- `%s`: %s" % (path, ", ".join("`%s`" % x for x in targets)))
    else:
        lines.append("No Make/Just targets discovered.")
    lines += ["", "## Commands found in guidance/CI", ""]
    lines.extend("- `%s`" % x for x in (data["commands"] or ["No command safely inferred."]))
    lines += ["", "## Execution rule", "", "Use the existing canonical flow. Start with a dry-run or smoke check; capture tool versions, configuration, seed, command, exit status, and log path under the project's established run convention."]
    return "\n".join(lines) + "\n"


def render_dv(data):
    roles = data["role_paths"]
    lines = [GENERATED_FILE, "# Design and verification index", "", "This index separates design, verification, flow, and protected boundaries so an agent can choose the correct evidence.", "", "## Design", ""]
    lines.extend(bullet_paths(roles.get("RTL / HDL source", []), 40))
    lines += ["", "## Verification", ""]
    lines.extend(bullet_paths(roles.get("verification source", []), 40))
    lines += ["", "## Constraints and flow", ""]
    lines.extend(bullet_paths(roles.get("constraints / power intent", []) + roles.get("build / EDA flow input", []) + roles.get("project manifest", []), 40))
    lines += ["", "## Heuristic HDL tops", ""]
    if data["probable_tops"]:
        lines.append("- `%s` — verify against source ordering/filelists before compiling." % "`, `".join(data["probable_tops"]))
    else:
        lines.append("- None discovered; use the canonical project manifest.")
    lines += ["", "## Missing evidence to resolve", "", "- Exact top/configuration, clock/reset assumptions, test selection, coverage/signoff criteria, and generated-source provenance are not inferred unless documented above."]
    return "\n".join(lines) + "\n"


def render_frontier(data):
    return """<!-- organize-chip-project:generated-file -->
# Execution frontier

## Objective

Keep the repository understandable and reproducible while preserving design and verification behavior.

## Baseline and evidence

- Inventory generated by `organize-chip-project`; see `docs/ai-native/repository-map.md`.
- Canonical commands: see `docs/ai-native/commands.md`; unknown commands remain explicitly unknown.
- Before functional edits, record Git revision, environment, command, result, and log path here.

## Completed

- Generated the fact-based Agent-Native navigation layer.

## Current state and blockers

- No implementation or verification status is inferred by this document. Confirm the project's own reports and CI.

## Exact next action

- Read `AGENTS.md`, then the relevant source-of-truth files and command index; run the smallest established smoke check.

## Acceptance criteria and residual risk

- Every functional migration has a path map, pre/post preservation snapshot, and proportionate compile/simulation/formal/lint/synthesis evidence.
- Heuristic inventory entries require human confirmation before being treated as authoritative.
"""


def update_agents(path, block, apply):
    if path.exists():
        original = read_text(path)
        if GENERATED_BEGIN in original and GENERATED_END in original:
            pattern = re.compile(re.escape(GENERATED_BEGIN) + r".*?" + re.escape(GENERATED_END), re.S)
            updated = pattern.sub(block, original, count=1)
        else:
            updated = original.rstrip() + "\n\n" + block + "\n"
    else:
        updated = "# Project guide\n\n" + block + "\n"
    if apply and (not path.exists() or updated != read_text(path)):
        path.write_text(updated, encoding="utf-8")
    return updated != (read_text(path) if path.exists() else "")


def write_generated(path, content, apply, refresh):
    """Only refresh files the generator owns; preserve ordinary project documentation."""
    existing = read_text(path) if path.exists() else ""
    if not path.exists():
        action = "create"
    elif existing == content:
        action = "unchanged"
    elif refresh and is_generator_owned(path):
        action = "refresh"
    else:
        action = "preserve"
    if apply and action in {"create", "refresh"}:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    return action


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    parser.add_argument("--apply", action="store_true", help="Write missing generated docs")
    parser.add_argument("--update-agents", action="store_true", help="Update only the generated block in AGENTS.md")
    parser.add_argument("--refresh-generated", action="store_true", help="Refresh only docs already marked as generator-owned")
    parser.add_argument("--output", type=Path, help="Write inventory JSON here instead of docs/ai-native/inventory.json")
    args = parser.parse_args()
    root = args.root.resolve()
    if not root.is_dir():
        parser.error("project root is not a directory: %s" % root)
    data = inspect(root)
    generated = {
        "docs/ai-native/repository-map.md": render_repository_map(data),
        "docs/ai-native/commands.md": render_commands(data),
        "docs/ai-native/design-verification-index.md": render_dv(data),
        "docs/exec-plans/active/execution-frontier.md": render_frontier(data),
    }
    inventory_path = args.output or (root / "docs/ai-native/inventory.json")
    try:
        inventory_key = str(inventory_path.resolve().relative_to(root))
    except ValueError:
        inventory_key = str(inventory_path)
    generated[inventory_key] = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    generated["AGENTS.md"] = None

    print("project root: %s" % root)
    print("discovered %d files, %d HDL modules, %d command(s)" % (data["file_count"], len(data["hdl_modules"]), len(data["commands"])))
    for relative, content in generated.items():
        if relative == "AGENTS.md":
            continue
        path = root / relative if not os.path.isabs(relative) else Path(relative)
        action = write_generated(path, content, False, args.refresh_generated)
        print("%s: %s" % (action, path))
        write_generated(path, content, args.apply, args.refresh_generated)
    if args.update_agents:
        print("update: %s (generated block only)" % (root / "AGENTS.md"))
        if args.apply:
            update_agents(root / "AGENTS.md", generated_block(data), True)
    else:
        print("preserve: %s (use --update-agents to refresh only the generated block)" % (root / "AGENTS.md"))
    print(("applied" if args.apply else "dry-run") + "; functional files were not moved or modified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

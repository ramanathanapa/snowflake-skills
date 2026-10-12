#!/usr/bin/env python3
"""Structural checks for this repository. Exits 1 on any error.

    python scripts/validate.py

Checks the marketplace, every plugin under plugins/ (manifest, CHANGELOG version, skills, references,
checks scripts, eval cases), relative Markdown links, and secret-like strings.
For the authoritative plugin check, also run: claude plugin validate . --strict
PyYAML is used for eval cases when installed (CI installs it); otherwise they get text checks only.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".git", "results", "node_modules", "__pycache__"}
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
REF_RE = re.compile(r"`(references/[\w.-]+\.md)`")
ASSET_RE = re.compile(r"`((?:checks|assets)/[\w.-]+\.\w+)`")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
CHECK_ID_RE = re.compile(r"\b(P\d\d-\d\d)\b")
SECRET_RE = re.compile(
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----"
    r"|AKIA[0-9A-Z]{16}"
    r"|(?i:password\s*[:=]\s*['\"][^'\"\s]{6,}['\"])"
)
NO_CHECKLIST_NEEDED = {"pitfalls", "review-audit"}

errors: list[str] = []
warnings: list[str] = []
counts = {"plugins": 0, "skills": 0, "evals": 0, "checks": 0}
try:
    import yaml
except ImportError:
    yaml = None
    warnings.append("PyYAML not installed: eval cases get text checks only (pip install pyyaml)")


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def files(*suffixes):
    for p in ROOT.rglob("*"):
        if p.is_file() and p.suffix in suffixes and not SKIP_DIRS & set(p.relative_to(ROOT).parts):
            yield p


def frontmatter(text):
    m = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n", text, re.S)
    if not m:
        return None
    return {k.strip(): v.strip() for k, v in (l.split(":", 1) for l in m.group(1).splitlines()
                                             if ":" in l and not l.startswith((" ", "\t", "-")))}


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        errors.append(f"{rel(path)}: missing")
    except json.JSONDecodeError as e:
        errors.append(f"{rel(path)}: invalid JSON ({e})")
    return None


def check_skill(skill_md: Path):
    folder, text = skill_md.parent, skill_md.read_text(encoding="utf-8")
    fm = frontmatter(text)
    if fm is None:
        errors.append(f"{rel(skill_md)}: missing YAML frontmatter")
        return
    name, desc = fm.get("name", ""), fm.get("description", "")
    if name != folder.name:
        errors.append(f"{rel(skill_md)}: name '{name}' must equal its folder name '{folder.name}'")
    if not NAME_RE.match(name) or len(name) > 64:
        errors.append(f"{rel(skill_md)}: name must be kebab-case and at most 64 characters")
    if not desc:
        errors.append(f"{rel(skill_md)}: description is empty")
    elif len(desc) > 1024:
        errors.append(f"{rel(skill_md)}: description is {len(desc)} characters (max 1024)")
    if len(text.splitlines()) > 500:
        warnings.append(f"{rel(skill_md)}: over 500 lines; move detail into references/")
    routed = set(REF_RE.findall(text))
    for ref in sorted(routed):
        if not (folder / ref).is_file():
            errors.append(f"{rel(skill_md)}: routes to missing file {ref}")
    ref_texts = {}
    for ref_file in sorted((folder / "references").glob("*.md")):
        t = ref_texts[ref_file.stem] = ref_file.read_text(encoding="utf-8")
        if f"references/{ref_file.name}" not in routed:
            errors.append(f"{rel(ref_file)}: exists but SKILL.md never routes to it")
        if "> Read when:" not in t:
            warnings.append(f"{rel(ref_file)}: missing the '> Read when:' line")
        if ref_file.stem not in NO_CHECKLIST_NEEDED and not re.search(r"^## .*checklist", t, re.M | re.I):
            errors.append(f"{rel(ref_file)}: area reference needs a '## ... Checklist' section")
    # checks/ and assets/ mentioned anywhere in the skill must exist
    for md in [skill_md, *(folder / "references").glob("*.md")]:
        for target in set(ASSET_RE.findall(md.read_text(encoding="utf-8"))):
            if not (folder / target).is_file():
                errors.append(f"{rel(md)}: mentions missing file {target}")
    # automated checklist items and SQL checks must agree, ID for ID
    checks_dir = folder / "checks"
    if checks_dir.is_dir():
        sql_ids = set()
        for sql in checks_dir.glob("*.sql"):
            sql_ids |= set(re.findall(r"'(P\d\d-\d\d)'", sql.read_text(encoding="utf-8")))
        counts["checks"] += len(sql_ids)
        automated = {i for t in ref_texts.values() for line in t.splitlines()
                     if "(automated" in line for i in CHECK_ID_RE.findall(line)}
        for i in sorted(automated - sql_ids):
            errors.append(f"{rel(folder)}: checklist marks {i} automated but no checks/*.sql inserts it")
        for i in sorted(sql_ids - automated):
            errors.append(f"{rel(folder)}: checks/*.sql inserts {i} but no checklist marks it automated")
    counts["skills"] += 1


def check_evals(plugin: Path):
    for case in sorted((plugin / "evals").glob("*/case.yaml")):
        counts["evals"] += 1
        text = case.read_text(encoding="utf-8")
        if yaml is None:
            for key in ("schema_version:", "name:", "prompt:", "graders:", "type:"):
                if key not in text:
                    errors.append(f"{rel(case)}: missing '{key}'")
            continue
        try:
            doc = yaml.safe_load(text)
        except yaml.YAMLError as e:
            errors.append(f"{rel(case)}: invalid YAML ({e})")
            continue
        if doc.get("schema_version") != "1.1":
            errors.append(f"{rel(case)}: schema_version must be \"1.1\"")
        if doc.get("name") != case.parent.name:
            errors.append(f"{rel(case)}: name must equal its folder name '{case.parent.name}'")
        if not (doc.get("execution") or {}).get("prompt"):
            errors.append(f"{rel(case)}: execution.prompt is empty")
        graders = doc.get("graders") or []
        if not graders:
            errors.append(f"{rel(case)}: case has no graders")
        for g in graders:
            if not g.get("name") or not g.get("type"):
                errors.append(f"{rel(case)}: every grader needs 'name' and 'type'")
            elif g["type"] == "llm" and not g.get("criteria"):
                errors.append(f"{rel(case)}: llm grader '{g['name']}' has no criteria")


# 1. Marketplace and plugins
market = load_json(ROOT / ".claude-plugin/marketplace.json")
plugin_dirs = sorted(p.parent.parent for p in (ROOT / "plugins").glob("*/.claude-plugin/plugin.json"))
if (ROOT / ".claude-plugin/plugin.json").exists():
    errors.append(".claude-plugin/plugin.json: the repo root is a marketplace only; plugins live under plugins/")
if market:
    for key in ("name", "owner", "plugins"):
        if key not in market:
            errors.append(f"marketplace.json: missing '{key}'")
    entries = {e.get("name"): e for e in market.get("plugins", [])}
    for e in entries.values():
        src = e.get("source", "")
        if not isinstance(src, str) or ".." in src or not (ROOT / src / ".claude-plugin/plugin.json").is_file():
            errors.append(f"marketplace.json: entry '{e.get('name')}' has a bad source '{src}'")
    for d in plugin_dirs:
        if d.name not in entries:
            errors.append(f"marketplace.json: plugin '{d.name}' is not listed")
for plugin in plugin_dirs:
    counts["plugins"] += 1
    manifest = load_json(plugin / ".claude-plugin/plugin.json")
    if not manifest:
        continue
    pname = manifest.get("name", "")
    if pname != plugin.name:
        errors.append(f"{rel(plugin)}: plugin.json name '{pname}' must equal the folder name")
    if re.match(r"^(claude|anthropic|cc-plugin)", pname, re.I):
        errors.append(f"{rel(plugin)}: names starting with claude/anthropic/cc-plugin are reserved")
    for key in ("version", "description", "author", "license"):
        if key not in manifest:
            errors.append(f"{rel(plugin)}: plugin.json missing '{key}'")
    changelog = plugin / "CHANGELOG.md"
    if not changelog.exists():
        errors.append(f"{rel(plugin)}: missing CHANGELOG.md")
    else:
        m = re.search(r"^## \[(\d+\.\d+\.\d+)\]", changelog.read_text(encoding="utf-8"), re.M)
        if not m:
            errors.append(f"{rel(changelog)}: no released version heading like '## [1.0.0] - YYYY-MM-DD'")
        elif m.group(1) != manifest.get("version"):
            errors.append(f"{rel(plugin)}: version {manifest.get('version')} differs from CHANGELOG {m.group(1)}")
    skills = sorted((plugin / "skills").glob("*/SKILL.md"))
    if not skills:
        errors.append(f"{rel(plugin)}: no skills/*/SKILL.md")
    for s in skills:
        check_skill(s)
    check_evals(plugin)

# 2. Relative Markdown links resolve
for md in files(".md"):
    for target in LINK_RE.findall(md.read_text(encoding="utf-8")):
        if re.match(r"^(https?:|mailto:|#)", target):
            continue
        path = target.split("#", 1)[0]
        if path and not (md.parent / path).exists():
            errors.append(f"{rel(md)}: broken link '{target}'")

# 3. Secret-like strings
this_file = Path(__file__).resolve()
for f in files(".md", ".json", ".yml", ".yaml", ".py", ".txt", ".toml", ".tf", ".sql"):
    if f.resolve() != this_file and SECRET_RE.search(f.read_text(encoding="utf-8", errors="ignore")):
        errors.append(f"{rel(f)}: contains something that looks like a secret")

for w in warnings:
    print(f"warning: {w}")
for e in errors:
    print(f"error:   {e}")
print(f"\n{counts['plugins']} plugin(s), {counts['skills']} skill(s), {counts['evals']} eval case(s), "
      f"{counts['checks']} automated check(s): {len(errors)} error(s), {len(warnings)} warning(s)")
sys.exit(1 if errors else 0)

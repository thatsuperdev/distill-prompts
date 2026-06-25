#!/usr/bin/env bash
set -e

REPO="eternalsayed/distill-prompts"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
SKILL_NAME="distill"
SKILL_FILE="distill.skill.md"

# ── Install paths ─────────────────────────────────────────────────────────────
# SKILL.md-based agents
CLAUDE_SKILL_DIR="${HOME}/.claude/skills/${SKILL_NAME}"
CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
CLINE_SKILL_DIR="${HOME}/.cline/skills/${SKILL_NAME}"
KILO_SKILL_DIR="${HOME}/.kilo/skills/${SKILL_NAME}"
AMP_SKILL_DIR="${HOME}/.amp/skills/${SKILL_NAME}"
OPENCODE_SKILL_DIR="${HOME}/.config/opencode/skills/${SKILL_NAME}"
GEMINI_SKILL_DIR="${HOME}/.gemini/skills/${SKILL_NAME}"
ANTIGRAVITY_SKILL_DIR="${HOME}/.gemini/config/skills/${SKILL_NAME}"

# Body-append / rules-based agents
CODEX_SKILL_DIR="${HOME}/.codex/skills/${SKILL_NAME}"
CODEX_AGENTS_MD="${HOME}/.codex/AGENTS.md"
CONTINUE_RULES_DIR="${HOME}/.continue/rules"
WINDSURF_RULES_DIR="${HOME}/.windsurf/rules"
AIDER_CONVENTIONS="${HOME}/.aider.distill.md"
AIDER_CONF="${HOME}/.aider.conf.yml"
CLAUDE_DESKTOP_APP_DIR="${HOME}/Library/Application Support/Claude"

# ── Flags ─────────────────────────────────────────────────────────────────────
INSTALL_CLAUDE=false
INSTALL_CODEX=false
INSTALL_CLINE=false
INSTALL_KILO=false
INSTALL_AMP=false
INSTALL_OPENCODE=false
INSTALL_GEMINI=false
INSTALL_ANTIGRAVITY=false
INSTALL_CONTINUE=false
INSTALL_WINDSURF=false
INSTALL_AIDER=false
INSTALL_CLAUDE_DESKTOP=false
AUTO=true

usage() {
  echo "Usage: install.sh [options]"
  echo ""
  echo "  (no flags)       auto-detect installed agents and install for all found"
  echo "  --all            install for all agents regardless of detection"
  echo ""
  echo "  --claude         Claude Code"
  echo "  --codex          Codex CLI"
  echo "  --cline          Cline (VS Code)"
  echo "  --kilo           KiloCode"
  echo "  --amp            Amp (Sourcegraph)"
  echo "  --opencode       OpenCode"
  echo "  --gemini         Gemini CLI"
  echo "  --antigravity    Antigravity"
  echo "  --continue       Continue.dev"
  echo "  --windsurf       Windsurf"
  echo "  --aider          Aider"
  echo "  --claude-desktop Claude desktop app (guided — uses skill-creator)"
  echo ""
  echo "  --help           show this message"
}

for arg in "$@"; do
  case "$arg" in
    --claude)      INSTALL_CLAUDE=true;      AUTO=false ;;
    --codex)       INSTALL_CODEX=true;       AUTO=false ;;
    --cline)       INSTALL_CLINE=true;       AUTO=false ;;
    --kilo)        INSTALL_KILO=true;        AUTO=false ;;
    --amp)         INSTALL_AMP=true;         AUTO=false ;;
    --opencode)    INSTALL_OPENCODE=true;    AUTO=false ;;
    --gemini)      INSTALL_GEMINI=true;      AUTO=false ;;
    --antigravity) INSTALL_ANTIGRAVITY=true; AUTO=false ;;
    --continue)    INSTALL_CONTINUE=true;    AUTO=false ;;
    --windsurf)    INSTALL_WINDSURF=true;    AUTO=false ;;
    --aider)          INSTALL_AIDER=true;          AUTO=false ;;
    --claude-desktop) INSTALL_CLAUDE_DESKTOP=true; AUTO=false ;;
    --all)
      INSTALL_CLAUDE=true; INSTALL_CODEX=true; INSTALL_CLINE=true
      INSTALL_KILO=true; INSTALL_AMP=true; INSTALL_OPENCODE=true
      INSTALL_GEMINI=true; INSTALL_ANTIGRAVITY=true; INSTALL_CONTINUE=true
      INSTALL_WINDSURF=true; INSTALL_AIDER=true; INSTALL_CLAUDE_DESKTOP=true
      AUTO=false ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown flag: $arg"; usage; exit 1 ;;
  esac
done

# ── Auto-detect ───────────────────────────────────────────────────────────────
if [ "$AUTO" = true ]; then
  command -v claude   >/dev/null 2>&1                                    && INSTALL_CLAUDE=true
  command -v codex    >/dev/null 2>&1                                    && INSTALL_CODEX=true
  [ -d "${HOME}/.cline" ]                                                && INSTALL_CLINE=true
  command -v kilo     >/dev/null 2>&1 || [ -d "${HOME}/.kilo" ]         && INSTALL_KILO=true
  command -v amp      >/dev/null 2>&1 || [ -d "${HOME}/.amp" ]          && INSTALL_AMP=true
  command -v opencode >/dev/null 2>&1 || [ -d "${HOME}/.config/opencode" ] && INSTALL_OPENCODE=true
  command -v gemini   >/dev/null 2>&1 || [ -d "${HOME}/.gemini/skills" ] && INSTALL_GEMINI=true
  [ -d "${HOME}/.gemini/antigravity" ] && INSTALL_ANTIGRAVITY=true
  [ -d "${HOME}/.continue" ]                                             && INSTALL_CONTINUE=true
  [ -d "${HOME}/.windsurf" ] || [ -d "${HOME}/.codeium/windsurf" ]      && INSTALL_WINDSURF=true
  command -v aider    >/dev/null 2>&1                                    && INSTALL_AIDER=true
  [ -d "${CLAUDE_DESKTOP_APP_DIR}" ]                                     && INSTALL_CLAUDE_DESKTOP=true
fi

# Check at least one target
NONE=true
for flag in "$INSTALL_CLAUDE" "$INSTALL_CODEX" "$INSTALL_CLINE" "$INSTALL_KILO" \
            "$INSTALL_AMP" "$INSTALL_OPENCODE" "$INSTALL_GEMINI" "$INSTALL_ANTIGRAVITY" \
            "$INSTALL_CONTINUE" "$INSTALL_WINDSURF" "$INSTALL_AIDER" "$INSTALL_CLAUDE_DESKTOP"; do
  [ "$flag" = true ] && NONE=false && break
done
if [ "$NONE" = true ]; then
  echo "No supported agents detected."
  echo "Use --all to install for all agents, or pick one with a flag (--help for list)."
  exit 1
fi

# ── Fetch skill once ──────────────────────────────────────────────────────────
TMP_SKILL=$(mktemp)
trap 'rm -f "$TMP_SKILL"' EXIT
if ! curl -fsSL "${RAW_BASE}/${SKILL_FILE}" -o "$TMP_SKILL"; then
  echo "Error: failed to fetch ${RAW_BASE}/${SKILL_FILE}"
  echo "Check your internet connection or try again."
  exit 1
fi

# Strip YAML frontmatter (--- ... ---) — used for agents that take plain markdown
# gsub handles Windows CRLF so the delimiter match works on any line ending
skill_body() {
  awk 'NR==1&&/^---\r?$/{skip=1;next} skip&&/^---\r?$/{skip=0;next} !skip{gsub(/\r$/,""); print}' "$1"
}

# ── Helpers ───────────────────────────────────────────────────────────────────
install_skill_md() {
  local dir="$1"
  mkdir -p "$dir"
  cp "$TMP_SKILL" "${dir}/SKILL.md"
  echo "  skill  → ${dir}/SKILL.md"
}

already_installed() {
  local file="$1" marker="$2"
  [ -f "$file" ] && grep -q "$marker" "$file" 2>/dev/null
}

# ── Claude Code ───────────────────────────────────────────────────────────────
install_claude() {
  echo "[claude]"
  install_skill_md "$CLAUDE_SKILL_DIR"

  local entry
  entry="
# distill
- **distill** (\`~/.claude/skills/distill/SKILL.md\`) — converts vague requests into clear AI-ready instructions. Trigger: \`/distill\`
When the user types \`/distill\`, invoke the Skill tool with \`skill: \"distill\"\` before doing anything else."

  if [ -f "$CLAUDE_MD" ]; then
    if already_installed "$CLAUDE_MD" 'skill: "distill"'; then
      echo "  CLAUDE.md already configured — skipping"
    else
      printf '%s\n' "$entry" >> "$CLAUDE_MD"
      echo "  CLAUDE.md → ${CLAUDE_MD}"
    fi
  else
    echo "  No CLAUDE.md at ${CLAUDE_MD} — create it and add:${entry}"
  fi
  echo "  Trigger: /distill"
}

# ── Codex ─────────────────────────────────────────────────────────────────────
install_codex() {
  echo "[codex]"
  install_skill_md "$CODEX_SKILL_DIR"
  if [ ! -f "$CODEX_AGENTS_MD" ]; then
    mkdir -p "$(dirname "$CODEX_AGENTS_MD")"
    touch "$CODEX_AGENTS_MD"
    echo "  created ${CODEX_AGENTS_MD}"
  fi
  if already_installed "$CODEX_AGENTS_MD" "## Distill"; then
    echo "  AGENTS.md already has Distill — skipping"
  else
    printf '\n## Distill\n\nWhen a request is prefixed with `distill this:` or `/distill`, apply the Distill skill before answering.\n' >> "$CODEX_AGENTS_MD"
    echo "  AGENTS.md → ${CODEX_AGENTS_MD}"
  fi
  echo "  Trigger: /distill or distill this: <request>"
}

# ── Cline ─────────────────────────────────────────────────────────────────────
install_cline() {
  echo "[cline]"
  install_skill_md "$CLINE_SKILL_DIR"
  echo "  Trigger: /distill  (enable Skills in Cline settings if not already on)"
}

# ── KiloCode ──────────────────────────────────────────────────────────────────
install_kilo() {
  echo "[kilo]"
  install_skill_md "$KILO_SKILL_DIR"
  echo "  Trigger: /distill"
}

# ── Amp ───────────────────────────────────────────────────────────────────────
install_amp() {
  echo "[amp]"
  install_skill_md "$AMP_SKILL_DIR"
  echo "  Trigger: /distill"
}

# ── OpenCode ──────────────────────────────────────────────────────────────────
install_opencode() {
  echo "[opencode]"
  install_skill_md "$OPENCODE_SKILL_DIR"
  echo "  Trigger: /distill"
}

# ── Gemini CLI ────────────────────────────────────────────────────────────────
install_gemini() {
  echo "[gemini]"
  install_skill_md "$GEMINI_SKILL_DIR"
  echo "  Trigger: distill this: <request>"
}

# ── Antigravity ───────────────────────────────────────────────────────────────
install_antigravity() {
  echo "[antigravity]"
  install_skill_md "$ANTIGRAVITY_SKILL_DIR"
  echo "  Trigger: /distill"
}

# ── Continue.dev ──────────────────────────────────────────────────────────────
install_continue() {
  echo "[continue]"
  mkdir -p "$CONTINUE_RULES_DIR"
  local dest="${CONTINUE_RULES_DIR}/distill.md"
  if [ -f "$dest" ]; then
    echo "  already installed — skipping"
  else
    skill_body "$TMP_SKILL" > "$dest"
    echo "  rule   → ${dest}"
  fi
  echo "  Active in all Agent/Chat/Edit sessions automatically"
}

# ── Windsurf ──────────────────────────────────────────────────────────────────
install_windsurf() {
  echo "[windsurf]"
  mkdir -p "$WINDSURF_RULES_DIR"
  local dest="${WINDSURF_RULES_DIR}/global_rules.md"
  if already_installed "$dest" "## Distill"; then
    echo "  global_rules.md already has Distill — skipping"
  else
    { printf '\n## Distill\n\n'; skill_body "$TMP_SKILL"; } >> "$dest"
    echo "  rules  → ${dest}"
  fi
  echo "  Trigger: distill this: <request>"
}

# ── Aider ─────────────────────────────────────────────────────────────────────
install_aider() {
  echo "[aider]"
  skill_body "$TMP_SKILL" > "$AIDER_CONVENTIONS"
  echo "  conventions → ${AIDER_CONVENTIONS}"

  if already_installed "$AIDER_CONF" "aider.distill"; then
    echo "  ${AIDER_CONF} already references distill — skipping"
  elif [ -f "$AIDER_CONF" ]; then
    echo "  Add this to ${AIDER_CONF} to auto-load on every session:"
    echo "    read:"
    echo "      - ${AIDER_CONVENTIONS}"
  else
    printf 'read:\n  - %s\n' "$AIDER_CONVENTIONS" > "$AIDER_CONF"
    echo "  conf   → ${AIDER_CONF}"
  fi
  echo "  Or load manually: aider --read ${AIDER_CONVENTIONS}"
}

# ── Claude desktop app ────────────────────────────────────────────────────────
install_claude_desktop() {
  echo "[claude-desktop]"
  echo "  Claude desktop uses Cowork's account-scoped skill system."
  echo "  Copying skill content to clipboard and opening the app..."

  # Copy skill body (no frontmatter) to clipboard — macOS only
  if command -v pbcopy >/dev/null 2>&1; then
    skill_body "$TMP_SKILL" | pbcopy
    echo "  clipboard ← skill content copied"
  else
    echo "  (pbcopy not available — copy the skill body manually from distill.skill.md)"
  fi

  # Open the Claude desktop app
  if open -a "Claude" 2>/dev/null; then
    echo "  opened Claude desktop app"
  else
    echo "  Could not open Claude automatically — open it manually"
  fi

  echo ""
  echo "  In Claude, start a new chat and run:"
  echo "    skill-creator"
  echo "  When prompted for content, paste with ⌘V."
  echo "  Name it 'distill' and trigger with /distill."
}

# ── Run ───────────────────────────────────────────────────────────────────────
echo "Installing Distill..."
echo ""
[ "$INSTALL_CLAUDE" = true ]      && install_claude      && echo ""
[ "$INSTALL_CODEX" = true ]       && install_codex       && echo ""
[ "$INSTALL_CLINE" = true ]       && install_cline       && echo ""
[ "$INSTALL_KILO" = true ]        && install_kilo        && echo ""
[ "$INSTALL_AMP" = true ]         && install_amp         && echo ""
[ "$INSTALL_OPENCODE" = true ]    && install_opencode    && echo ""
[ "$INSTALL_GEMINI" = true ]      && install_gemini      && echo ""
[ "$INSTALL_ANTIGRAVITY" = true ] && install_antigravity && echo ""
[ "$INSTALL_CONTINUE" = true ]    && install_continue    && echo ""
[ "$INSTALL_WINDSURF" = true ]    && install_windsurf    && echo ""
[ "$INSTALL_AIDER" = true ]          && install_aider          && echo ""
[ "$INSTALL_CLAUDE_DESKTOP" = true ] && install_claude_desktop && echo ""

echo "Done."
echo ""
echo "Note: Cursor requires manual setup — add Distill to Settings → Rules for AI."
echo "      Paste the body of distill.skill.md (below the --- frontmatter)."
echo ""
echo "Always-on mode: https://github.com/${REPO}#always-on-mode"

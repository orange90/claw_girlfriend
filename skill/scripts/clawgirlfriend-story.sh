#!/bin/bash
# clawgirlfriend-story.sh
# Generate a multi-image photo story (2-3 connected selfies) simulating a day's journey
#
# Usage: ./clawgirlfriend-story.sh "<story_theme>" "<channel>"
#
# Examples:
#   ./clawgirlfriend-story.sh "day out shopping in Seoul" "#general"
#   ./clawgirlfriend-story.sh "cozy Sunday at home" "#friends"
#
# Environment variables:
#   IMAGE_PROVIDER          - Image provider (same as clawgirlfriend-selfie.sh)
#   CLAWRA_SKILL_DIR        - Path to installed skill directory

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $1"; }

# ─── Config ────────────────────────────────────────────────────────────────────

THEME="${1:-}"
CHANNEL="${2:-}"
SKILL_DIR="${CLAWRA_SKILL_DIR:-$HOME/.openclaw/skills/clawgirlfriend-selfie}"
SELFIE_SCRIPT="$SKILL_DIR/scripts/clawgirlfriend-selfie.sh"

if [ -z "$THEME" ] || [ -z "$CHANNEL" ]; then
    echo "Usage: $0 <story_theme> <channel>"
    echo ""
    echo "Examples:"
    echo "  $0 \"shopping in Seoul\" \"#general\""
    echo "  $0 \"cozy Sunday at home\" \"#friends\""
    echo "  $0 \"day at the beach\" \"#summer\""
    exit 1
fi

if [ ! -f "$SELFIE_SCRIPT" ]; then
    log_error "selfie script not found: $SELFIE_SCRIPT"
    exit 1
fi

# ─── Story generator ──────────────────────────────────────────────────────────

# Generate a 3-part story based on theme
generate_story_parts() {
    local theme="$1"

    # Detect story type from theme keywords
    if echo "$theme" | grep -qiE "shopping|mall|store|boutique"; then
        echo "getting ready to go shopping, cute outfit, mirror selfie at home"
        echo "browsing in a trendy store, surrounded by clothes, excited smile"
        echo "after shopping, carrying bags, happy and tired, street background"
    elif echo "$theme" | grep -qiE "beach|ocean|sea|summer"; then
        echo "getting ready for beach day, summer outfit, sunscreen vibes"
        echo "at the beach, sun-kissed, waves in background, summer vibes"
        echo "sunset at the beach, golden hour lighting, relaxed and happy"
    elif echo "$theme" | grep -qiE "cafe|coffee|brunch|breakfast"; then
        echo "morning walk to the cafe, fresh air, cozy streetwear"
        echo "at a cozy cafe with latte art, warm lighting, reading"
        echo "leaving cafe, happy and caffeinated, afternoon sunlight"
    elif echo "$theme" | grep -qiE "home|cozy|sunday|lazy|rest"; then
        echo "lazy morning in bed, messy hair, cozy pajamas, soft light"
        echo "making snacks at home, casual home clothes, happy cooking"
        echo "relaxing on couch with phone, cozy blanket, evening lamp light"
    elif echo "$theme" | grep -qiE "night|party|club|dinner|date"; then
        echo "getting ready for the night, doing makeup, elegant outfit"
        echo "at a lively restaurant or venue, glowing atmosphere, excited"
        echo "end of the night, slightly tired but happy, city lights background"
    else
        # Generic story arc: preparation → main event → wrap-up
        echo "getting ready, stylish outfit, mirror selfie"
        echo "in the middle of ${theme}, enjoying the moment"
        echo "heading home from ${theme}, happy and content, evening light"
    fi
}

# Generate captions for each part
generate_captions() {
    local theme="$1"
    echo "Getting ready~ ✨"
    echo "Having so much fun! 😊"
    echo "What a day~ 💕"
}

# ─── Execute story ────────────────────────────────────────────────────────────

log_step "Generating photo story: $THEME"

# Read story parts into array (bash 3 compatible — macOS ships bash 3.2)
STORY_PARTS=()
while IFS= read -r line; do STORY_PARTS+=("$line"); done < <(generate_story_parts "$THEME")
CAPTIONS=()
while IFS= read -r line; do CAPTIONS+=("$line"); done < <(generate_captions "$THEME")

TOTAL=${#STORY_PARTS[@]}
log_info "Story has $TOTAL parts"

for i in "${!STORY_PARTS[@]}"; do
    PART="${STORY_PARTS[$i]}"
    CAPTION="${CAPTIONS[$i]:-✨}"
    PART_NUM=$((i + 1))

    log_step "Part $PART_NUM/$TOTAL: $PART"

    bash "$SELFIE_SCRIPT" "$PART" "$CHANNEL" "$CAPTION"

    # Wait between sends to simulate real chat timing
    if [ "$PART_NUM" -lt "$TOTAL" ]; then
        DELAY=$((2 + RANDOM % 4))
        log_info "Waiting ${DELAY}s before next part..."
        sleep "$DELAY"
    fi
done

log_info "Photo story complete! ($TOTAL images sent)"

echo ""
echo "--- Story Result ---"
jq -n \
    --arg theme "$THEME" \
    --arg channel "$CHANNEL" \
    --argjson parts "$TOTAL" \
    '{success: true, theme: $theme, channel: $channel, parts_sent: $parts}'

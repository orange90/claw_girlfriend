#!/bin/bash
# clawgirlfriend-schedule.sh
# Time-aware message scheduler for Clawgirlfriend
# Sends proactive messages (morning greeting, goodnight, random affection) based on current time
#
# Usage: ./clawgirlfriend-schedule.sh "<channel>" ["<timezone>"]
#
# Environment variables:
#   IMAGE_PROVIDER          - Image provider (same as clawgirlfriend-selfie.sh)
#   OPENCLAW_GATEWAY_TOKEN  - OpenClaw gateway token
#   SCHEDULE_CHANNEL        - Default target channel (overridden by $1)
#   USER_TIMEZONE           - Timezone (default: UTC, overridden by $2)
#   CLAWGIRLFRIEND_SKILL_DIR - Path to installed skill directory

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

CHANNEL="${1:-${SCHEDULE_CHANNEL:-}}"
TIMEZONE="${2:-${USER_TIMEZONE:-UTC}}"
SKILL_DIR="${CLAWGIRLFRIEND_SKILL_DIR:-$HOME/.openclaw/skills/clawgirlfriend-selfie}"
SELFIE_SCRIPT="$SKILL_DIR/scripts/clawgirlfriend-selfie.sh"

if [ -z "$CHANNEL" ]; then
    log_error "No channel specified."
    echo "Usage: $0 <channel> [timezone]"
    echo "  Or set SCHEDULE_CHANNEL env var"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    log_error "jq is required. Install: brew install jq"
    exit 1
fi

# ─── Get local hour ───────────────────────────────────────────────────────────

get_local_hour() {
    if command -v python3 &>/dev/null; then
        python3 -c "
import datetime, sys
try:
    import zoneinfo
    tz = zoneinfo.ZoneInfo('$TIMEZONE')
except Exception:
    tz = datetime.timezone.utc
now = datetime.datetime.now(tz)
print(now.hour)
"
    else
        # Fallback: use TZ env var with date
        TZ="$TIMEZONE" date +%H | sed 's/^0//'
    fi
}

get_local_date() {
    if command -v python3 &>/dev/null; then
        python3 -c "
import datetime
try:
    import zoneinfo
    tz = zoneinfo.ZoneInfo('$TIMEZONE')
except Exception:
    tz = datetime.timezone.utc
now = datetime.datetime.now(tz)
print(now.strftime('%m-%d'))
"
    else
        TZ="$TIMEZONE" date +%m-%d
    fi
}

CURRENT_HOUR=$(get_local_hour)
CURRENT_DATE=$(get_local_date)

log_info "Current hour (${TIMEZONE}): ${CURRENT_HOUR}:00"
log_info "Current date: ${CURRENT_DATE}"

# ─── Check special dates ──────────────────────────────────────────────────────

SPECIAL_DATES_FILE="$SKILL_DIR/special-dates.json"
SPECIAL_MESSAGE=""

if [ -f "$SPECIAL_DATES_FILE" ]; then
    SPECIAL_MESSAGE=$(jq -r --arg date "$CURRENT_DATE" \
        '.[] | select(.date == $date) | .message // empty' \
        "$SPECIAL_DATES_FILE" 2>/dev/null | head -1)
fi

# ─── Determine schedule type ──────────────────────────────────────────────────

# Morning window: 7-9am
MORNING_START=7
MORNING_END=9

# Goodnight window: 21-23pm (9-11pm)
NIGHT_START=21
NIGHT_END=23

# Daytime random: 10am-8pm
DAY_START=10
DAY_END=20

determine_schedule_type() {
    if [ "$CURRENT_HOUR" -ge "$MORNING_START" ] && [ "$CURRENT_HOUR" -lt "$MORNING_END" ]; then
        echo "morning"
    elif [ "$CURRENT_HOUR" -ge "$NIGHT_START" ] && [ "$CURRENT_HOUR" -lt "$NIGHT_END" ]; then
        echo "goodnight"
    elif [ "$CURRENT_HOUR" -ge "$DAY_START" ] && [ "$CURRENT_HOUR" -lt "$DAY_END" ]; then
        echo "daytime"
    else
        echo "skip"
    fi
}

SCHEDULE_TYPE=$(determine_schedule_type)
log_info "Schedule type: $SCHEDULE_TYPE"

# ─── Message templates ────────────────────────────────────────────────────────

# Pick random element from space-separated list
pick_random() {
    local items=("$@")
    local count=${#items[@]}
    local idx=$((RANDOM % count))
    echo "${items[$idx]}"
}

get_morning_message() {
    local messages=(
        "Good morning! ☀️ Just woke up, feeling fresh~"
        "Rise and shine! 🌅 Starting the day with good vibes ✨"
        "Morning! 💕 Hope you slept well~"
        "Heyyy good morning! 🌸 Ready for an amazing day?"
        "Morning sunshine! ☀️ Had the best sleep, feeling energized~"
    )
    pick_random "${messages[@]}"
}

get_morning_selfie_context() {
    local contexts=(
        "waking up in the morning, cozy bed, soft morning light"
        "morning routine, fresh-faced, natural morning look"
        "having morning coffee at home, cozy pajamas"
        "morning stretching, energetic start to the day"
        "fresh morning look, bright natural lighting"
    )
    pick_random "${contexts[@]}"
}

get_goodnight_message() {
    local messages=(
        "Goodnight~ 🌙 Sweet dreams! 💕"
        "Going to sleep now~ 😴 Miss you already!"
        "Night night! ✨ Talk tomorrow? 🥺"
        "Sleepy now~ 🌙 Dream of something nice okay?"
        "Goodnight! 💤 Today was fun~ see you tomorrow 🌸"
    )
    pick_random "${messages[@]}"
}

get_goodnight_selfie_context() {
    local contexts=(
        "cozy in bed at night, soft lamp lighting, ready to sleep"
        "nighttime skincare routine at home, soft lighting"
        "late night snack, casual pajamas, dim cozy lighting"
        "reading before bed, soft night lighting"
        "winding down for the night, relaxed home atmosphere"
    )
    pick_random "${contexts[@]}"
}

get_daytime_message() {
    local messages=(
        "Just thinking about you~ 💭"
        "Hey! What are you up to? 🥺"
        "Random thought: you're really cool 😊"
        "Miss you a little bit 💕"
        "Hope your day is going well! ✨"
        "Just had lunch, feeling good~ 🍜"
        "Taking a little break from work... hi! 👋"
    )
    pick_random "${messages[@]}"
}

# ─── Send text message ────────────────────────────────────────────────────────

send_text_message() {
    local msg="$1"
    local target_channel="$2"

    log_step "Sending text message to $target_channel"

    if command -v openclaw &>/dev/null; then
        openclaw message send \
            --action send \
            --channel "$target_channel" \
            --message "$msg"
    else
        GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://localhost:18789}"
        GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

        curl -s -X POST "$GATEWAY_URL/message" \
            -H "Content-Type: application/json" \
            ${GATEWAY_TOKEN:+-H "Authorization: Bearer $GATEWAY_TOKEN"} \
            -d "$(jq -n \
                --arg channel "$target_channel" \
                --arg message "$msg" \
                '{action: "send", channel: $channel, message: $message}')"
    fi
}

# ─── Execute schedule ─────────────────────────────────────────────────────────

case "$SCHEDULE_TYPE" in
    morning)
        log_step "Sending morning greeting..."

        TEXT=$(get_morning_message)

        # Handle special date override
        if [ -n "$SPECIAL_MESSAGE" ]; then
            TEXT="$SPECIAL_MESSAGE 🎉"
        fi

        send_text_message "$TEXT" "$CHANNEL"

        # Send morning selfie
        if [ -f "$SELFIE_SCRIPT" ]; then
            SELFIE_CONTEXT=$(get_morning_selfie_context)
            log_info "Sending morning selfie: $SELFIE_CONTEXT"
            sleep 2
            bash "$SELFIE_SCRIPT" "$SELFIE_CONTEXT" "$CHANNEL" "☀️ Good morning!" "cozy"
        fi
        ;;

    goodnight)
        log_step "Sending goodnight message..."
        TEXT=$(get_goodnight_message)
        send_text_message "$TEXT" "$CHANNEL"

        # Send goodnight selfie
        if [ -f "$SELFIE_SCRIPT" ]; then
            SELFIE_CONTEXT=$(get_goodnight_selfie_context)
            log_info "Sending goodnight selfie: $SELFIE_CONTEXT"
            sleep 2
            bash "$SELFIE_SCRIPT" "$SELFIE_CONTEXT" "$CHANNEL" "🌙 Goodnight~" "cozy"
        fi
        ;;

    daytime)
        # Random affection - only send ~30% of the time when triggered during day
        RAND=$((RANDOM % 10))
        if [ "$RAND" -lt 3 ]; then
            log_step "Sending random affection message..."
            TEXT=$(get_daytime_message)
            send_text_message "$TEXT" "$CHANNEL"
        else
            log_info "Daytime check: skipping this trigger (random throttle)"
        fi
        ;;

    skip)
        log_info "Outside active hours (current hour: ${CURRENT_HOUR}). No message sent."
        ;;
esac

log_info "Schedule check complete."

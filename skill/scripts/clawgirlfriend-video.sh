#!/bin/bash
# clawgirlfriend-video.sh
# Generate short video/animation from a selfie image using video AI providers
#
# Usage: ./clawgirlfriend-video.sh "<prompt>" "<channel>" ["<image_url>"]
#
# Environment variables:
#   VIDEO_PROVIDER          - kling | runway | jimeng (default: kling)
#   KLING_API_KEY           - 可灵 Kling API key (China-accessible)
#   RUNWAY_API_KEY          - Runway Gen-3 API key
#   JIMENG_API_KEY          - 即梦 AI API key (China-accessible)
#   REFERENCE_IMAGE_URL     - Source image URL for image-to-video
#   OPENCLAW_GATEWAY_TOKEN  - OpenClaw gateway token

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

PROMPT="${1:-}"
CHANNEL="${2:-}"
SOURCE_IMAGE="${3:-${REFERENCE_IMAGE_URL:-https://cdn.jsdelivr.net/gh/SumeLabs/clawra@main/assets/clawra.png}}"
VIDEO_PROVIDER="${VIDEO_PROVIDER:-kling}"

if [ -z "$PROMPT" ] || [ -z "$CHANNEL" ]; then
    echo "Usage: $0 <prompt> <channel> [image_url]"
    echo ""
    echo "Video Providers (set VIDEO_PROVIDER env var):"
    echo "  kling    可灵 Kling by Kuaishou (China-accessible, requires KLING_API_KEY)"
    echo "  runway   Runway Gen-3 Alpha (requires RUNWAY_API_KEY)"
    echo "  jimeng   即梦 AI by ByteDance (China-accessible, requires JIMENG_API_KEY)"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    log_error "jq is required."
    exit 1
fi

# ─── Provider: 可灵 Kling (Kuaishou) ─────────────────────────────────────────

generate_kling() {
    local prompt="$1"
    local image_url="$2"

    if [ -z "${KLING_API_KEY:-}" ]; then
        log_error "KLING_API_KEY not set. Get your key: https://klingai.com"
        exit 1
    fi

    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg prompt "$prompt" \
        --arg image_url "$image_url" \
        '{
            model: "kling-v1",
            image: $image_url,
            prompt: $prompt,
            duration: 5,
            aspect_ratio: "9:16"
        }')

    log_info "Submitting Kling video task..."
    local RESPONSE
    RESPONSE=$(curl -s -X POST "https://api.klingai.com/v1/videos/image2video" \
        -H "Authorization: Bearer $KLING_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    if echo "$RESPONSE" | jq -e '.code != 0' >/dev/null 2>&1; then
        log_error "Kling error: $(echo "$RESPONSE" | jq -r '.message // .msg')"
        exit 1
    fi

    local TASK_ID
    TASK_ID=$(echo "$RESPONSE" | jq -r '.data.task_id')
    log_info "Kling task submitted: $TASK_ID"

    # Poll for result (up to 3 minutes)
    local MAX_POLLS=36
    local POLL_COUNT=0
    while [ $POLL_COUNT -lt $MAX_POLLS ]; do
        sleep 5
        POLL_COUNT=$((POLL_COUNT + 1))

        local POLL_RESPONSE
        POLL_RESPONSE=$(curl -s \
            "https://api.klingai.com/v1/videos/image2video/$TASK_ID" \
            -H "Authorization: Bearer $KLING_API_KEY")

        local STATUS
        STATUS=$(echo "$POLL_RESPONSE" | jq -r '.data.task_status')
        log_info "Kling status: $STATUS ($POLL_COUNT/$MAX_POLLS)"

        if [ "$STATUS" = "succeed" ]; then
            echo "$POLL_RESPONSE" | jq -r '.data.task_result.videos[0].url'
            return
        fi
        if [ "$STATUS" = "failed" ]; then
            log_error "Kling task failed: $(echo "$POLL_RESPONSE" | jq -r '.data.task_status_msg // "unknown"')"
            exit 1
        fi
    done

    log_error "Kling video generation timed out"
    exit 1
}

# ─── Provider: Runway Gen-3 ───────────────────────────────────────────────────

generate_runway() {
    local prompt="$1"
    local image_url="$2"

    if [ -z "${RUNWAY_API_KEY:-}" ]; then
        log_error "RUNWAY_API_KEY not set. Get your key: https://runwayml.com"
        exit 1
    fi

    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg prompt "$prompt" \
        --arg image_url "$image_url" \
        '{
            model: "gen3a_turbo",
            promptImage: $image_url,
            promptText: $prompt,
            duration: 5,
            ratio: "720p",
            watermark: false
        }')

    log_info "Submitting Runway video task..."
    local RESPONSE
    RESPONSE=$(curl -s -X POST "https://api.dev.runwayml.com/v1/image_to_video" \
        -H "Authorization: Bearer $RUNWAY_API_KEY" \
        -H "Content-Type: application/json" \
        -H "X-Runway-Version: 2024-11-06" \
        -d "$PAYLOAD")

    local TASK_ID
    TASK_ID=$(echo "$RESPONSE" | jq -r '.id')
    if [ -z "$TASK_ID" ] || [ "$TASK_ID" = "null" ]; then
        log_error "Runway error: $(echo "$RESPONSE" | jq -r '.error // .message')"
        exit 1
    fi
    log_info "Runway task submitted: $TASK_ID"

    # Poll for result (up to 3 minutes)
    local MAX_POLLS=36
    local POLL_COUNT=0
    while [ $POLL_COUNT -lt $MAX_POLLS ]; do
        sleep 5
        POLL_COUNT=$((POLL_COUNT + 1))

        local POLL_RESPONSE
        POLL_RESPONSE=$(curl -s \
            "https://api.dev.runwayml.com/v1/tasks/$TASK_ID" \
            -H "Authorization: Bearer $RUNWAY_API_KEY" \
            -H "X-Runway-Version: 2024-11-06")

        local STATUS
        STATUS=$(echo "$POLL_RESPONSE" | jq -r '.status')
        log_info "Runway status: $STATUS ($POLL_COUNT/$MAX_POLLS)"

        if [ "$STATUS" = "SUCCEEDED" ]; then
            echo "$POLL_RESPONSE" | jq -r '.output[0]'
            return
        fi
        if [ "$STATUS" = "FAILED" ]; then
            log_error "Runway task failed: $(echo "$POLL_RESPONSE" | jq -r '.failure // "unknown"')"
            exit 1
        fi
    done

    log_error "Runway video generation timed out"
    exit 1
}

# ─── Provider: 即梦 AI (ByteDance) ───────────────────────────────────────────

generate_jimeng() {
    local prompt="$1"
    local image_url="$2"

    if [ -z "${JIMENG_API_KEY:-}" ]; then
        log_error "JIMENG_API_KEY not set. Get your key: https://jimeng.jianying.com"
        exit 1
    fi

    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg prompt "$prompt" \
        --arg image_url "$image_url" \
        '{
            req_key: "img2video_ai_generate_video",
            prompt: $prompt,
            image_urls: [$image_url],
            duration: 5,
            resolution: "720p"
        }')

    log_info "Submitting 即梦 video task..."
    local RESPONSE
    RESPONSE=$(curl -s -X POST "https://visual.volcengineapi.com/?Action=CVSubmitTask&Version=2022-08-31" \
        -H "Authorization: Bearer $JIMENG_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    local TASK_ID
    TASK_ID=$(echo "$RESPONSE" | jq -r '.data.task_id')
    if [ -z "$TASK_ID" ] || [ "$TASK_ID" = "null" ]; then
        log_error "即梦 error: $(echo "$RESPONSE" | jq -r '.message // "unknown error"')"
        exit 1
    fi
    log_info "即梦 task submitted: $TASK_ID"

    # Poll for result (up to 3 minutes)
    local MAX_POLLS=36
    local POLL_COUNT=0
    while [ $POLL_COUNT -lt $MAX_POLLS ]; do
        sleep 5
        POLL_COUNT=$((POLL_COUNT + 1))

        local POLL_RESPONSE
        POLL_RESPONSE=$(curl -s \
            "https://visual.volcengineapi.com/?Action=CVGetResult&Version=2022-08-31&task_id=$TASK_ID" \
            -H "Authorization: Bearer $JIMENG_API_KEY")

        local STATUS
        STATUS=$(echo "$POLL_RESPONSE" | jq -r '.data.status')
        log_info "即梦 status: $STATUS ($POLL_COUNT/$MAX_POLLS)"

        if [ "$STATUS" = "success" ]; then
            echo "$POLL_RESPONSE" | jq -r '.data.resp_data.video_url'
            return
        fi
        if [ "$STATUS" = "fail" ]; then
            log_error "即梦 task failed"
            exit 1
        fi
    done

    log_error "即梦 video generation timed out"
    exit 1
}

# ─── Generate video ───────────────────────────────────────────────────────────

log_step "Generating video (provider: $VIDEO_PROVIDER)..."
log_info "Prompt: $PROMPT"
log_info "Source image: $SOURCE_IMAGE"

VIDEO_URL=""
case "$VIDEO_PROVIDER" in
    kling)   VIDEO_URL=$(generate_kling "$PROMPT" "$SOURCE_IMAGE") ;;
    runway)  VIDEO_URL=$(generate_runway "$PROMPT" "$SOURCE_IMAGE") ;;
    jimeng)  VIDEO_URL=$(generate_jimeng "$PROMPT" "$SOURCE_IMAGE") ;;
    *)
        log_error "Unknown VIDEO_PROVIDER: $VIDEO_PROVIDER"
        log_error "Valid: kling, runway, jimeng"
        exit 1
        ;;
esac

if [ -z "$VIDEO_URL" ]; then
    log_error "Failed to get video URL from provider"
    exit 1
fi

log_info "Video ready: $VIDEO_URL"

# ─── Send via OpenClaw ────────────────────────────────────────────────────────

IFS=',' read -ra CHANNELS <<< "$CHANNEL"
for CH in "${CHANNELS[@]}"; do
    CH=$(echo "$CH" | xargs)
    log_step "Sending video to: $CH"

    if command -v openclaw &>/dev/null; then
        openclaw message send \
            --action send \
            --channel "$CH" \
            --message "🎬" \
            --media "$VIDEO_URL"
    else
        GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://localhost:18789}"
        GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

        curl -s -X POST "$GATEWAY_URL/message" \
            -H "Content-Type: application/json" \
            ${GATEWAY_TOKEN:+-H "Authorization: Bearer $GATEWAY_TOKEN"} \
            -d "$(jq -n \
                --arg channel "$CH" \
                --arg media "$VIDEO_URL" \
                '{action: "send", channel: $channel, message: "🎬", media: $media}')"
    fi

    log_info "Video sent to $CH"
done

log_info "Done!"

echo ""
echo "--- Video Result ---"
jq -n \
    --arg url "$VIDEO_URL" \
    --arg channel "$CHANNEL" \
    --arg prompt "$PROMPT" \
    --arg provider "$VIDEO_PROVIDER" \
    '{success: true, video_url: $url, channel: $channel, prompt: $prompt, provider: $provider}'

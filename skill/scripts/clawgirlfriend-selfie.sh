#!/bin/bash
# clawgirlfriend-selfie.sh
# Generate an image with a chosen AI provider and send it via OpenClaw
#
# Usage: ./clawgirlfriend-selfie.sh "<prompt>" "<channel>" ["<caption>"] ["<mode>"]
#
# Environment variables:
#   IMAGE_PROVIDER          - falai | siliconflow | tongyi | zhipu | google | replicate
#                             (default: falai)
#   REFERENCE_IMAGE_URL     - Override default reference image URL
#   FAL_KEY                 - fal.ai API key
#   SILICONFLOW_API_KEY     - Silicon Flow API key
#   DASHSCOPE_API_KEY       - 通义万相 (Aliyun DashScope) API key
#   ZHIPU_API_KEY           - 智谱 CogView API key
#   GOOGLE_API_KEY          - Google Imagen API key
#   REPLICATE_API_KEY       - Replicate API key
#   SILICONFLOW_MODEL       - (default: black-forest-labs/FLUX.1-schnell)
#   TONGYI_MODEL            - (default: wanx2.1-t2i-turbo)
#   ZHIPU_MODEL             - (default: cogview-4)
#   GOOGLE_MODEL            - (default: imagen-3.0-fast-generate-001)
#   REPLICATE_MODEL         - (default: black-forest-labs/flux-schnell)
#   OPENCLAW_GATEWAY_URL    - (default: http://localhost:18789)
#   OPENCLAW_GATEWAY_TOKEN  - optional

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

PROVIDER="${IMAGE_PROVIDER:-falai}"
REFERENCE_IMAGE="${REFERENCE_IMAGE_URL:-https://cdn.jsdelivr.net/gh/SumeLabs/clawra@main/assets/clawra.png}"

PROMPT="${1:-}"
CHANNEL="${2:-}"
CAPTION="${3:-✨}"
MODE="${4:-auto}"

if [ -z "$PROMPT" ] || [ -z "$CHANNEL" ]; then
    echo "Usage: $0 <prompt> <channel> [caption] [mode]"
    echo ""
    echo "Providers (set IMAGE_PROVIDER env var):"
    echo "  falai        fal.ai Grok Imagine (global, requires VPN in China)"
    echo "  siliconflow  Silicon Flow 硅基流动 (China-accessible, free tier)"
    echo "  tongyi       通义万相 Aliyun DashScope (China-native, free tier)"
    echo "  zhipu        智谱 CogView (China-native, free tier)"
    echo "  google       Google Imagen nano banana2 (global)"
    echo "  replicate    Replicate FLUX/SDXL (global)"
    echo ""
    echo "Selfie modes (set via MODE arg or auto-detected from prompt):"
    echo "  mirror   Full-body mirror selfie (outfit/fashion)"
    echo "  direct   Close-up direct selfie (location/portrait)"
    echo "  anime    Anime/illustration style"
    echo "  vintage  Film/retro aesthetic"
    echo "  artistic Art photography style"
    echo "  action   Dynamic motion capture"
    echo "  cozy     Casual home atmosphere"
    echo "  night    Night scene/party lighting"
    exit 1
fi

# Check for jq
if ! command -v jq &>/dev/null; then
    log_error "jq is required. Install: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
fi

# Check for openclaw
if command -v openclaw &>/dev/null; then
    USE_CLI=true
else
    log_warn "openclaw CLI not found - will attempt direct API call"
    USE_CLI=false
fi

# ─── Mode detection ────────────────────────────────────────────────────────────

detect_mode() {
    local context="$1"
    if echo "$context" | grep -qiE "anime|cartoon|drawn|illustrated|2d|chibi|manga"; then
        echo "anime"
    elif echo "$context" | grep -qiE "vintage|film|retro|90s|polaroid|grainy|kodak"; then
        echo "vintage"
    elif echo "$context" | grep -qiE "artistic|art|painting|aesthetic|editorial|fine art"; then
        echo "artistic"
    elif echo "$context" | grep -qiE "dancing|running|jumping|action|moving|spinning|workout"; then
        echo "action"
    elif echo "$context" | grep -qiE "home|pajamas|morning|cozy|bed|blanket|indoor|waking"; then
        echo "cozy"
    elif echo "$context" | grep -qiE "night out|party|club|neon|bar|nightlife|evening out"; then
        echo "night"
    elif echo "$context" | grep -qiE "outfit|wearing|clothes|dress|suit|fashion|full-body|mirror"; then
        echo "mirror"
    elif echo "$context" | grep -qiE "cafe|restaurant|beach|park|city|location|portrait|face|eyes|smile"; then
        echo "direct"
    else
        echo "mirror"
    fi
}

# ─── Prompt builder ───────────────────────────────────────────────────────────

build_prompt() {
    local context="$1"
    local mode="$2"
    case "$mode" in
        mirror)
            echo "make a pic of this person, but ${context}. the person is taking a mirror selfie"
            ;;
        direct)
            echo "a close-up selfie taken by herself at ${context}, direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie, phone held at arm's length, face fully visible"
            ;;
        anime)
            echo "anime illustration style portrait of this person, ${context}, vibrant colors, clean linework, expressive eyes, kawaii aesthetic, manga-inspired"
            ;;
        vintage)
            echo "vintage film photograph of this person, ${context}, grainy film texture, warm tones, retro color grading, kodachrome aesthetic, slightly faded edges"
            ;;
        artistic)
            echo "fine art photography portrait of this person, ${context}, editorial style, dramatic lighting, artistic composition, high fashion aesthetic"
            ;;
        action)
            echo "dynamic action shot of this person, ${context}, motion blur, energetic pose, candid movement, high shutter speed feel"
            ;;
        cozy)
            echo "cozy casual photo of this person, ${context}, soft natural lighting, relaxed atmosphere, warm home environment, candid and natural"
            ;;
        night)
            echo "nighttime photo of this person, ${context}, neon lights bokeh, dramatic shadows, vibrant nightlife atmosphere, moody evening lighting"
            ;;
        *)
            echo "make a pic of this person, but ${context}. the person is taking a mirror selfie"
            ;;
    esac
}

# Auto-detect mode if needed
if [ "$MODE" = "auto" ]; then
    MODE=$(detect_mode "$PROMPT")
    log_info "Auto-detected mode: $MODE"
fi

# If the prompt looks like raw user context (not already a full prompt), build it
# Check if PROMPT already looks like a full constructed prompt
if ! echo "$PROMPT" | grep -qiE "^(make a pic|a close-up selfie|anime illustration|vintage film|fine art|dynamic action|cozy casual|nighttime photo)"; then
    PROMPT=$(build_prompt "$PROMPT" "$MODE")
fi

log_step "Provider: $PROVIDER | Mode: $MODE"
log_info "Prompt: $PROMPT"

# ─── Provider: fal.ai ──────────────────────────────────────────────────────────

generate_falai() {
    if [ -z "${FAL_KEY:-}" ]; then
        log_error "FAL_KEY not set. Get your key: https://fal.ai/dashboard/keys"
        exit 1
    fi

    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg image_url "$REFERENCE_IMAGE" \
        --arg prompt "$1" \
        '{image_url: $image_url, prompt: $prompt, num_images: 1, output_format: "jpeg"}')

    local RESPONSE
    RESPONSE=$(curl -s -X POST "https://fal.run/xai/grok-imagine-image/edit" \
        -H "Authorization: Key $FAL_KEY" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
        log_error "fal.ai error: $(echo "$RESPONSE" | jq -r '.error // .detail')"
        exit 1
    fi

    echo "$RESPONSE" | jq -r '.images[0].url'
}

# ─── Provider: Silicon Flow ────────────────────────────────────────────────────

generate_siliconflow() {
    if [ -z "${SILICONFLOW_API_KEY:-}" ]; then
        log_error "SILICONFLOW_API_KEY not set. Get your key: https://cloud.siliconflow.cn"
        exit 1
    fi

    local MODEL="${SILICONFLOW_MODEL:-black-forest-labs/FLUX.1-schnell}"
    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "$1" \
        '{model: $model, prompt: $prompt, image_size: "1024x1024", num_inference_steps: 20, num_images: 1}')

    local RESPONSE
    RESPONSE=$(curl -s -X POST "https://api.siliconflow.cn/v1/images/generations" \
        -H "Authorization: Bearer $SILICONFLOW_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
        log_error "SiliconFlow error: $(echo "$RESPONSE" | jq -r '.error.message // .error')"
        exit 1
    fi

    echo "$RESPONSE" | jq -r '.images[0].url'
}

# ─── Provider: 通义万相 (Aliyun DashScope) ────────────────────────────────────

generate_tongyi() {
    if [ -z "${DASHSCOPE_API_KEY:-}" ]; then
        log_error "DASHSCOPE_API_KEY not set. Get your key: https://dashscope.aliyun.com"
        exit 1
    fi

    local MODEL="${TONGYI_MODEL:-wanx2.1-t2i-turbo}"
    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "$1" \
        '{model: $model, input: {prompt: $prompt}, parameters: {size: "1024*1024", n: 1}}')

    # Submit async task
    local SUBMIT_RESPONSE
    SUBMIT_RESPONSE=$(curl -s -X POST \
        "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis" \
        -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
        -H "Content-Type: application/json" \
        -H "X-DashScope-Async: enable" \
        -d "$PAYLOAD")

    if echo "$SUBMIT_RESPONSE" | jq -e '.code' >/dev/null 2>&1; then
        log_error "通义万相 error: $(echo "$SUBMIT_RESPONSE" | jq -r '.message // .code')"
        exit 1
    fi

    local TASK_ID
    TASK_ID=$(echo "$SUBMIT_RESPONSE" | jq -r '.output.task_id')
    log_info "通义万相 task submitted: $TASK_ID"

    # Poll for result (up to 90 seconds)
    local MAX_POLLS=30
    local POLL_COUNT=0
    while [ $POLL_COUNT -lt $MAX_POLLS ]; do
        sleep 3
        POLL_COUNT=$((POLL_COUNT + 1))

        local POLL_RESPONSE
        POLL_RESPONSE=$(curl -s \
            "https://dashscope.aliyuncs.com/api/v1/tasks/$TASK_ID" \
            -H "Authorization: Bearer $DASHSCOPE_API_KEY")

        local STATUS
        STATUS=$(echo "$POLL_RESPONSE" | jq -r '.output.task_status')
        log_info "Task status: $STATUS ($POLL_COUNT/$MAX_POLLS)"

        if [ "$STATUS" = "SUCCEEDED" ]; then
            echo "$POLL_RESPONSE" | jq -r '.output.results[0].url'
            return
        fi
        if [ "$STATUS" = "FAILED" ]; then
            local MSG
            MSG=$(echo "$POLL_RESPONSE" | jq -r '.output.message // "unknown"')
            log_error "通义万相 task failed: $MSG"
            exit 1
        fi
    done

    log_error "通义万相 task timed out after 90 seconds"
    exit 1
}

# ─── Provider: 智谱 CogView ───────────────────────────────────────────────────

generate_zhipu() {
    if [ -z "${ZHIPU_API_KEY:-}" ]; then
        log_error "ZHIPU_API_KEY not set. Get your key: https://open.bigmodel.cn"
        exit 1
    fi

    local MODEL="${ZHIPU_MODEL:-cogview-4}"
    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg model "$MODEL" \
        --arg prompt "$1" \
        '{model: $model, prompt: $prompt, size: "1024x1024"}')

    local RESPONSE
    RESPONSE=$(curl -s -X POST "https://open.bigmodel.cn/api/paas/v4/images/generations" \
        -H "Authorization: Bearer $ZHIPU_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
        log_error "智谱 error: $(echo "$RESPONSE" | jq -r '.error.message // .error')"
        exit 1
    fi

    echo "$RESPONSE" | jq -r '.data[0].url'
}

# ─── Provider: Google Imagen (nano banana2) ───────────────────────────────────

generate_google() {
    if [ -z "${GOOGLE_API_KEY:-}" ]; then
        log_error "GOOGLE_API_KEY not set. Get your key: https://aistudio.google.com/app/apikey"
        exit 1
    fi

    local MODEL="${GOOGLE_MODEL:-imagen-3.0-fast-generate-001}"
    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg prompt "$1" \
        '{instances: [{prompt: $prompt}], parameters: {sampleCount: 1}}')

    local RESPONSE
    RESPONSE=$(curl -s -X POST \
        "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:predict?key=${GOOGLE_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
        log_error "Google Imagen error: $(echo "$RESPONSE" | jq -r '.error.message // .error')"
        exit 1
    fi

    # Google returns base64 — save to temp file
    local B64
    B64=$(echo "$RESPONSE" | jq -r '.predictions[0].bytesBase64Encoded')
    local TMP_FILE
    TMP_FILE="/tmp/clawgirlfriend-selfie-$(date +%s).jpeg"
    echo "$B64" | base64 --decode > "$TMP_FILE"
    log_info "Google Imagen: image saved to $TMP_FILE"
    echo "$TMP_FILE"
}

# ─── Provider: Replicate ──────────────────────────────────────────────────────

generate_replicate() {
    if [ -z "${REPLICATE_API_KEY:-}" ]; then
        log_error "REPLICATE_API_KEY not set. Get your key: https://replicate.com/account/api-tokens"
        exit 1
    fi

    local MODEL="${REPLICATE_MODEL:-black-forest-labs/flux-schnell}"
    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg prompt "$1" \
        '{input: {prompt: $prompt, num_outputs: 1}}')

    # Create prediction with Prefer: wait (sync if fast enough)
    local CREATE_RESPONSE
    CREATE_RESPONSE=$(curl -s -X POST \
        "https://api.replicate.com/v1/models/${MODEL}/predictions" \
        -H "Authorization: Bearer $REPLICATE_API_KEY" \
        -H "Content-Type: application/json" \
        -H "Prefer: wait" \
        -d "$PAYLOAD")

    local STATUS
    STATUS=$(echo "$CREATE_RESPONSE" | jq -r '.status')

    if [ "$STATUS" = "succeeded" ]; then
        echo "$CREATE_RESPONSE" | jq -r '.output[0]'
        return
    fi

    if echo "$CREATE_RESPONSE" | jq -e '.detail' >/dev/null 2>&1; then
        log_error "Replicate error: $(echo "$CREATE_RESPONSE" | jq -r '.detail')"
        exit 1
    fi

    # Poll for result
    local GET_URL
    GET_URL=$(echo "$CREATE_RESPONSE" | jq -r '.urls.get')
    local MAX_POLLS=30
    local POLL_COUNT=0

    while [ $POLL_COUNT -lt $MAX_POLLS ]; do
        sleep 2
        POLL_COUNT=$((POLL_COUNT + 1))

        local POLL_RESPONSE
        POLL_RESPONSE=$(curl -s "$GET_URL" \
            -H "Authorization: Bearer $REPLICATE_API_KEY")

        STATUS=$(echo "$POLL_RESPONSE" | jq -r '.status')
        log_info "Replicate status: $STATUS ($POLL_COUNT/$MAX_POLLS)"

        if [ "$STATUS" = "succeeded" ]; then
            echo "$POLL_RESPONSE" | jq -r '.output[0]'
            return
        fi
        if [ "$STATUS" = "failed" ]; then
            log_error "Replicate failed: $(echo "$POLL_RESPONSE" | jq -r '.error // "unknown"')"
            exit 1
        fi
    done

    log_error "Replicate timed out after 60 seconds"
    exit 1
}

# ─── Generate image ───────────────────────────────────────────────────────────

log_step "Generating image..."

IMAGE_URL=""
case "$PROVIDER" in
    falai)       IMAGE_URL=$(generate_falai "$PROMPT") ;;
    siliconflow) IMAGE_URL=$(generate_siliconflow "$PROMPT") ;;
    tongyi)      IMAGE_URL=$(generate_tongyi "$PROMPT") ;;
    zhipu)       IMAGE_URL=$(generate_zhipu "$PROMPT") ;;
    google)      IMAGE_URL=$(generate_google "$PROMPT") ;;
    replicate)   IMAGE_URL=$(generate_replicate "$PROMPT") ;;
    *)
        log_error "Unknown IMAGE_PROVIDER: $PROVIDER"
        log_error "Valid: falai, siliconflow, tongyi, zhipu, google, replicate"
        exit 1
        ;;
esac

if [ -z "$IMAGE_URL" ]; then
    log_error "Failed to get image URL from provider"
    exit 1
fi

log_info "Image ready: $IMAGE_URL"

# ─── Send via OpenClaw (supports multi-channel) ───────────────────────────────

send_to_channel() {
    local TARGET_CHANNEL="$1"
    log_step "Sending to channel: $TARGET_CHANNEL"

    if [ "$USE_CLI" = true ]; then
        openclaw message send \
            --action send \
            --channel "$TARGET_CHANNEL" \
            --message "$CAPTION" \
            --media "$IMAGE_URL"
    else
        GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://localhost:18789}"
        GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

        curl -s -X POST "$GATEWAY_URL/message" \
            -H "Content-Type: application/json" \
            ${GATEWAY_TOKEN:+-H "Authorization: Bearer $GATEWAY_TOKEN"} \
            -d "$(jq -n \
                --arg channel "$TARGET_CHANNEL" \
                --arg message "$CAPTION" \
                --arg media "$IMAGE_URL" \
                '{action: "send", channel: $channel, message: $message, media: $media}')"
    fi
}

# Support comma-separated multi-channel broadcast
IFS=',' read -ra CHANNELS <<< "$CHANNEL"
for CH in "${CHANNELS[@]}"; do
    CH=$(echo "$CH" | xargs)  # trim whitespace
    send_to_channel "$CH"
    log_info "Sent to $CH"
done

log_info "Done! Image sent."

echo ""
echo "--- Result ---"
jq -n \
    --arg url "$IMAGE_URL" \
    --arg channel "$CHANNEL" \
    --arg prompt "$PROMPT" \
    --arg provider "$PROVIDER" \
    --arg mode "$MODE" \
    '{success: true, image_url: $url, channel: $channel, prompt: $prompt, provider: $provider, mode: $mode}'

#!/bin/bash
# clawgirlfriend-voice.sh
# Generate voice messages using TTS and send via OpenClaw
#
# Usage: ./clawgirlfriend-voice.sh "<text>" "<channel>"
#
# Environment variables:
#   TTS_PROVIDER            - edge | elevenlabs | aliyun (default: edge)
#   ELEVENLABS_API_KEY      - ElevenLabs API key
#   ALIYUN_TTS_KEY          - Aliyun TTS key
#   ELEVENLABS_VOICE_ID     - Voice ID (default: young female voice)
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

TEXT="${1:-}"
CHANNEL="${2:-}"
TTS_PROVIDER="${TTS_PROVIDER:-edge}"

if [ -z "$TEXT" ] || [ -z "$CHANNEL" ]; then
    echo "Usage: $0 <text> <channel>"
    echo ""
    echo "TTS Providers (set TTS_PROVIDER env var):"
    echo "  edge        Microsoft Edge TTS (free, no key needed, China-accessible)"
    echo "  elevenlabs  ElevenLabs (requires ELEVENLABS_API_KEY)"
    echo "  aliyun      Aliyun TTS (requires ALIYUN_TTS_KEY, China-accessible)"
    exit 1
fi

TMP_AUDIO="/tmp/clawgirlfriend-voice-$(date +%s).mp3"

# ─── Provider: Edge TTS (Microsoft, free) ────────────────────────────────────

generate_edge_tts() {
    local text="$1"
    local output="$2"

    # Check for edge-tts Python package
    if ! command -v edge-tts &>/dev/null && ! python3 -m edge_tts --help &>/dev/null; then
        log_warn "edge-tts not found. Installing..."
        pip3 install edge-tts --quiet || {
            log_error "Failed to install edge-tts. Run: pip3 install edge-tts"
            exit 1
        }
    fi

    # Young female voice (en-US-AriaNeural or zh-CN-XiaoxiaoNeural for Chinese)
    local VOICE="${EDGE_TTS_VOICE:-en-US-AriaNeural}"

    if command -v edge-tts &>/dev/null; then
        edge-tts --voice "$VOICE" --text "$text" --write-media "$output"
    else
        python3 -m edge_tts --voice "$VOICE" --text "$text" --write-media "$output"
    fi

    log_info "Edge TTS: audio saved to $output"
    echo "$output"
}

# ─── Provider: ElevenLabs ─────────────────────────────────────────────────────

generate_elevenlabs_tts() {
    local text="$1"
    local output="$2"

    if [ -z "${ELEVENLABS_API_KEY:-}" ]; then
        log_error "ELEVENLABS_API_KEY not set. Get your key: https://elevenlabs.io"
        exit 1
    fi

    # Default to a natural young female voice
    local VOICE_ID="${ELEVENLABS_VOICE_ID:-EXAVITQu4vr4xnSDxMaL}"  # Bella - soft female

    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg text "$text" \
        '{
            text: $text,
            model_id: "eleven_multilingual_v2",
            voice_settings: {stability: 0.5, similarity_boost: 0.75, style: 0.3, use_speaker_boost: true}
        }')

    curl -s -X POST \
        "https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}" \
        -H "xi-api-key: $ELEVENLABS_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        --output "$output"

    log_info "ElevenLabs TTS: audio saved to $output"
    echo "$output"
}

# ─── Provider: Aliyun TTS ─────────────────────────────────────────────────────

generate_aliyun_tts() {
    local text="$1"
    local output="$2"

    if [ -z "${ALIYUN_TTS_KEY:-}" ]; then
        log_error "ALIYUN_TTS_KEY not set. Get your key: https://nls.console.aliyun.com"
        exit 1
    fi

    local APP_KEY="${ALIYUN_TTS_APP_KEY:-}"
    if [ -z "$APP_KEY" ]; then
        log_error "ALIYUN_TTS_APP_KEY not set."
        exit 1
    fi

    # Use Aliyun NLS REST API — use jq to safely build JSON payload
    local PAYLOAD
    PAYLOAD=$(jq -n \
        --arg appkey "$APP_KEY" \
        --arg text "$text" \
        '{"appkey": $appkey, "text": $text, "format": "mp3", "voice": "aixia", "speech_rate": 0}')

    curl -s \
        "https://nls-gateway.cn-shanghai.aliyuncs.com/stream/v1/tts" \
        -X POST \
        -H "X-NLS-Token: $ALIYUN_TTS_KEY" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        --output "$output"

    log_info "Aliyun TTS: audio saved to $output"
    echo "$output"
}

# ─── Generate audio ───────────────────────────────────────────────────────────

log_step "Generating voice message (provider: $TTS_PROVIDER)..."
log_info "Text: $TEXT"

AUDIO_FILE=""
case "$TTS_PROVIDER" in
    edge)        AUDIO_FILE=$(generate_edge_tts "$TEXT" "$TMP_AUDIO") ;;
    elevenlabs)  AUDIO_FILE=$(generate_elevenlabs_tts "$TEXT" "$TMP_AUDIO") ;;
    aliyun)      AUDIO_FILE=$(generate_aliyun_tts "$TEXT" "$TMP_AUDIO") ;;
    *)
        log_error "Unknown TTS_PROVIDER: $TTS_PROVIDER"
        log_error "Valid: edge, elevenlabs, aliyun"
        exit 1
        ;;
esac

if [ -z "$AUDIO_FILE" ] || [ ! -f "$AUDIO_FILE" ]; then
    log_error "Failed to generate audio file"
    exit 1
fi

log_info "Audio ready: $AUDIO_FILE"

# ─── Send via OpenClaw ────────────────────────────────────────────────────────

log_step "Sending voice message to: $CHANNEL"

# Support comma-separated multi-channel
IFS=',' read -ra CHANNELS <<< "$CHANNEL"
for CH in "${CHANNELS[@]}"; do
    CH=$(echo "$CH" | xargs)

    if command -v openclaw &>/dev/null; then
        openclaw message send \
            --action send \
            --channel "$CH" \
            --media "$AUDIO_FILE"
    else
        GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://localhost:18789}"
        GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

        curl -s -X POST "$GATEWAY_URL/message" \
            -H "Content-Type: application/json" \
            ${GATEWAY_TOKEN:+-H "Authorization: Bearer $GATEWAY_TOKEN"} \
            -d "$(jq -n \
                --arg channel "$CH" \
                --arg media "$AUDIO_FILE" \
                '{action: "send", channel: $channel, media: $media}')"
    fi

    log_info "Voice sent to $CH"
done

# Clean up temp file
rm -f "$AUDIO_FILE"

log_info "Voice message delivered!"

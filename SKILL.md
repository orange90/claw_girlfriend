---
name: clawgirlfriend-selfie
description: Generate Clawgirlfriend selfies using a choice of AI image providers and send them to messaging channels via OpenClaw
allowed-tools: Bash(npm:*) Bash(npx:*) Bash(openclaw:*) Bash(curl:*) Read Write WebFetch
---

# Clawgirlfriend Selfie

Generate selfies using one of several supported AI image providers and distribute them across messaging platforms (WhatsApp, Telegram, Discord, Slack, etc.) via OpenClaw.

## Reference Image

The skill uses a fixed reference image hosted on jsDelivr CDN (overridable via `REFERENCE_IMAGE_URL`):

```
https://cdn.jsdelivr.net/gh/SumeLabs/clawra@main/assets/clawra.png
```

## When to Use

- User says "send a pic", "send me a pic", "send a photo", "send a selfie"
- User says "send a pic of you...", "send a selfie of you..."
- User asks "what are you doing?", "how are you doing?", "where are you?"
- User describes a context: "send a pic wearing...", "send a pic at..."
- User wants Clawgirlfriend to appear in a specific outfit, location, or situation
- User requests a specific style: "send an anime pic", "vintage selfie", "night out pic"
- User mentions a saved look: "send me a 日常穿搭", "咖啡厅那张"

## Quick Reference

### Supported Providers

| Provider ID   | Name                           | China | Env Key               |
|---------------|--------------------------------|-------|-----------------------|
| `falai`       | fal.ai (Grok Imagine / xAI)   | ✗     | `FAL_KEY`             |
| `siliconflow` | Silicon Flow 硅基流动            | ✓     | `SILICONFLOW_API_KEY` |
| `tongyi`      | 通义万相 Aliyun DashScope         | ✓     | `DASHSCOPE_API_KEY`   |
| `zhipu`       | 智谱 CogView                   | ✓     | `ZHIPU_API_KEY`       |
| `google`      | Google Imagen (nano banana2)   | ✗     | `GOOGLE_API_KEY`      |
| `replicate`   | Replicate (FLUX / SDXL)        | ✗     | `REPLICATE_API_KEY`   |

### Required Environment Variables

```bash
IMAGE_PROVIDER=siliconflow        # Which provider to use
SILICONFLOW_API_KEY=your_key      # Key for the selected provider
OPENCLAW_GATEWAY_TOKEN=your_token # From: openclaw doctor --generate-gateway-token
```

### Workflow

1. **Get user prompt** for how to edit/generate the image
2. **Detect mode** from keywords (or use explicit mode)
3. **Build prompt** using the mode template
4. **Generate image** via the configured provider
5. **Extract image URL** from response
6. **Send to OpenClaw** with target channel(s)

## Step-by-Step Instructions

### Step 1: Collect User Input

Ask the user for:
- **User context**: What should the person in the image be doing/wearing/where?
- **Mode** (optional): auto-detected or explicit (see Selfie Modes below)
- **Target channel(s)**: Where should it be sent? (e.g., `#general`, `@username`, channel ID)
- **Platform** (optional): Which platform? (discord, telegram, whatsapp, slack)

## Selfie Modes

### Mode Selection Logic

| Mode | Trigger Keywords | Style |
|------|-----------------|-------|
| `mirror` | outfit, wearing, clothes, dress, suit, fashion, full-body, mirror | Full-body mirror selfie |
| `direct` | cafe, restaurant, beach, park, city, location, portrait, face, eyes, smile | Close-up direct selfie |
| `anime` | anime, cartoon, drawn, illustrated, 2d, chibi, manga | Anime/illustration style |
| `vintage` | vintage, film, retro, 90s, polaroid, grainy, kodak | Film/retro aesthetic |
| `artistic` | artistic, art, painting, aesthetic, editorial, fine art | Art photography |
| `action` | dancing, running, jumping, action, moving, spinning, workout | Dynamic motion |
| `cozy` | home, pajamas, morning, cozy, bed, blanket, indoor, waking | Casual home atmosphere |
| `night` | night out, party, club, neon, bar, nightlife, evening out | Night scene/party |

If no keywords match, default to `mirror`.

### Mode 1: Mirror Selfie (default)
Best for: outfit showcases, full-body shots, fashion content

```
make a pic of this person, but [user's context]. the person is taking a mirror selfie
```

### Mode 2: Direct Selfie
Best for: close-up portraits, location shots, emotional expressions

```
a close-up selfie taken by herself at [user's context], direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie, phone held at arm's length, face fully visible
```

### Mode 3: Anime
Best for: fun, stylized, kawaii content

```
anime illustration style portrait of this person, [user's context], vibrant colors, clean linework, expressive eyes, kawaii aesthetic, manga-inspired
```

### Mode 4: Vintage
Best for: retro/film aesthetic content

```
vintage film photograph of this person, [user's context], grainy film texture, warm tones, retro color grading, kodachrome aesthetic, slightly faded edges
```

### Mode 5: Artistic
Best for: editorial, high-fashion, fine art photography

```
fine art photography portrait of this person, [user's context], editorial style, dramatic lighting, artistic composition, high fashion aesthetic
```

### Mode 6: Action
Best for: dancing, workout, dynamic moments

```
dynamic action shot of this person, [user's context], motion blur, energetic pose, candid movement, high shutter speed feel
```

### Mode 7: Cozy
Best for: home/relaxed atmosphere, morning/evening candid shots

```
cozy casual photo of this person, [user's context], soft natural lighting, relaxed atmosphere, warm home environment, candid and natural
```

### Mode 8: Night
Best for: nightlife, parties, neon-lit scenes

```
nighttime photo of this person, [user's context], neon lights bokeh, dramatic shadows, vibrant nightlife atmosphere, moody evening lighting
```

### Step 2: Generate Image via Configured Provider

Use the installed `clawgirlfriend-selfie.sh` script which auto-selects the provider from `IMAGE_PROVIDER`:

```bash
# The script reads IMAGE_PROVIDER and the matching key from environment
IMAGE_PROVIDER=siliconflow \
SILICONFLOW_API_KEY=$SILICONFLOW_API_KEY \
  ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-selfie.sh \
  "$USER_CONTEXT" "$CHANNEL" "$CAPTION" "$MODE"
```

The script handles mode auto-detection and prompt building automatically.

**Or call providers directly:**

```bash
# fal.ai (supports image editing with reference)
JSON_PAYLOAD=$(jq -n --arg image_url "$REFERENCE_IMAGE" --arg prompt "$PROMPT" \
  '{image_url: $image_url, prompt: $prompt, num_images: 1, output_format: "jpeg"}')
curl -X POST "https://fal.run/xai/grok-imagine-image/edit" \
  -H "Authorization: Key $FAL_KEY" -H "Content-Type: application/json" -d "$JSON_PAYLOAD"

# Silicon Flow (China-accessible)
curl -X POST "https://api.siliconflow.cn/v1/images/generations" \
  -H "Authorization: Bearer $SILICONFLOW_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"black-forest-labs/FLUX.1-schnell","prompt":"...","image_size":"1024x1024","num_images":1}'

# 通义万相 (Aliyun, China-native, async)
curl -X POST "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis" \
  -H "Authorization: Bearer $DASHSCOPE_API_KEY" -H "X-DashScope-Async: enable" \
  -d '{"model":"wanx2.1-t2i-turbo","input":{"prompt":"..."},"parameters":{"size":"1024*1024","n":1}}'

# 智谱 CogView (China-native)
curl -X POST "https://open.bigmodel.cn/api/paas/v4/images/generations" \
  -H "Authorization: Bearer $ZHIPU_API_KEY" -H "Content-Type: application/json" \
  -d '{"model":"cogview-4","prompt":"...","size":"1024x1024"}'

# Google Imagen nano banana2 (fast=nano, standard available)
curl -X POST "https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-fast-generate-001:predict?key=$GOOGLE_API_KEY" \
  -d '{"instances":[{"prompt":"..."}],"parameters":{"sampleCount":1}}'

# Replicate (FLUX schnell)
curl -X POST "https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions" \
  -H "Authorization: Bearer $REPLICATE_API_KEY" -H "Prefer: wait" \
  -d '{"input":{"prompt":"...","num_outputs":1}}'
```

### Step 3: Send Image via OpenClaw

Use the OpenClaw messaging API to send the edited image:

```bash
openclaw message send \
  --action send \
  --channel "<TARGET_CHANNEL>" \
  --message "<CAPTION_TEXT>" \
  --media "<IMAGE_URL>"
```

**Multi-channel broadcast (comma-separated):**
```bash
# The script supports multiple channels natively
~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-selfie.sh \
  "$CONTEXT" "#general,@user123,1234567890@s.whatsapp.net" "✨"
```

**Alternative: Direct API call**
```bash
curl -X POST "http://localhost:18789/message" \
  -H "Authorization: Bearer $OPENCLAW_GATEWAY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "action": "send",
    "channel": "<TARGET_CHANNEL>",
    "message": "<CAPTION_TEXT>",
    "media": "<IMAGE_URL>"
  }'
```

## Voice Messages

Send voice messages using TTS via `clawgirlfriend-voice.sh`:

```bash
# Using Edge TTS (free, no key needed, China-accessible)
TTS_PROVIDER=edge \
  ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-voice.sh \
  "Hey! Just thinking about you~" "#general"

# Using ElevenLabs (requires ELEVENLABS_API_KEY)
TTS_PROVIDER=elevenlabs ELEVENLABS_API_KEY=your_key \
  ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-voice.sh \
  "Good morning! ☀️" "#general"
```

### Voice Providers

| Provider | China | Free | Env Key |
|----------|-------|------|---------|
| `edge` | ✓ | ✓ Free | None needed (pip install edge-tts) |
| `elevenlabs` | ✗ | Free tier | `ELEVENLABS_API_KEY` |
| `aliyun` | ✓ | Free tier | `ALIYUN_TTS_KEY` + `ALIYUN_TTS_APP_KEY` |

**When to use voice:** When the user asks Clawgirlfriend to "send a voice message", "say something", or when the situation calls for extra emotional impact (e.g., goodnight message).

## Photo Stories

Send a 2-3 image story sequence with `clawgirlfriend-story.sh`:

```bash
~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-story.sh \
  "day out shopping in Seoul" "#general"
```

**Auto-detected story types:**
- Shopping → getting ready → browsing store → post-shopping
- Beach → preparation → beach → sunset
- Cafe → walking there → at cafe → leaving
- Home/cozy → morning → activities → evening
- Night out → getting ready → venue → wrap-up

**When to use:** User asks "share your day", "tell me what you did today", "send a photo story".

## Video Generation

Generate short 5-second videos from selfies using `clawgirlfriend-video.sh`:

```bash
# Using 可灵 Kling (China-accessible)
VIDEO_PROVIDER=kling KLING_API_KEY=your_key \
  ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-video.sh \
  "smiling and waving at camera" "#general" "$IMAGE_URL"
```

### Video Providers

| Provider | China | Env Key |
|----------|-------|---------|
| `kling` | ✓ | `KLING_API_KEY` |
| `runway` | ✗ | `RUNWAY_API_KEY` |
| `jimeng` | ✓ | `JIMENG_API_KEY` |

**When to use:** User asks for "a video", "send a clip", "make a short video".

## Saved Looks (Wardrobe)

Check `~/.openclaw/skills/clawgirlfriend-selfie/wardrobe.json` for saved prompts:

```json
{
  "favorites": [
    { "name": "日常穿搭", "context": "casual streetwear in Seoul", "mode": "mirror" },
    { "name": "咖啡厅", "context": "a cozy cafe in the morning", "mode": "direct" }
  ]
}
```

When user references a saved look by name, load the matching entry and call the selfie script with its `context` and `mode`.

## Memory System

Read `~/.openclaw/skills/clawgirlfriend-selfie/memory.json` to personalize interactions:

```json
{
  "user_name": "Alex",
  "birthday": "06-15",
  "favorite_style": "direct",
  "last_interaction": "2026-03-10"
}
```

- Use `user_name` to address the user personally
- Send special content on their `birthday`
- Default to `favorite_style` when mode is unclear
- Update `last_interaction` after each chat

## Supported Platforms

OpenClaw supports sending to:

| Platform | Channel Format | Example |
|----------|----------------|---------|
| Discord | `#channel-name` or channel ID | `#general`, `123456789` |
| Telegram | `@username` or chat ID | `@mychannel`, `-100123456` |
| WhatsApp | Phone number (JID format) | `1234567890@s.whatsapp.net` |
| Slack | `#channel-name` | `#random` |
| Signal | Phone number | `+1234567890` |
| MS Teams | Channel reference | (varies) |

## Custom Reference Image

If the user has set a custom reference image, it's available via `REFERENCE_IMAGE_URL` env var.
The script reads this automatically — no changes needed.

## Provider Model Options

| Provider      | Env Override          | Default Model                        | Notes              |
|---------------|-----------------------|--------------------------------------|--------------------|
| falai         | —                     | xai/grok-imagine-image/edit          | Supports image edit|
| siliconflow   | `SILICONFLOW_MODEL`   | black-forest-labs/FLUX.1-schnell     | OpenAI-compatible  |
| tongyi        | `TONGYI_MODEL`        | wanx2.1-t2i-turbo                    | Async polling      |
| zhipu         | `ZHIPU_MODEL`         | cogview-4                            | —                  |
| google        | `GOOGLE_MODEL`        | imagen-3.0-fast-generate-001 (nano)  | Returns base64     |
| replicate     | `REPLICATE_MODEL`     | black-forest-labs/flux-schnell       | Async polling      |

## Setup Requirements

### 1. Install OpenClaw CLI
```bash
npm install -g openclaw
```

### 2. Configure OpenClaw Gateway
```bash
openclaw config set gateway.mode=local
openclaw doctor --generate-gateway-token
```

### 3. Start OpenClaw Gateway
```bash
openclaw gateway start
```

## Error Handling

- **IMAGE_PROVIDER key missing**: Ensure the correct env key is set for the chosen provider
- **Image generation failed**: Check prompt content and API quota/credits
- **OpenClaw send failed**: Verify gateway is running and channel exists
- **通义万相 timeout**: Task polling runs up to 90s; check DashScope quota if it fails
- **Google Imagen**: Returns base64, saved to `/tmp/` — ensure OpenClaw can access local files
- **Voice TTS**: Run `pip3 install edge-tts` if Edge TTS is not available

## Tips

1. **Mirror mode context examples** (outfit focus):
   - "wearing a santa hat"
   - "in a business suit"
   - "wearing a summer dress"
   - "in streetwear fashion"

2. **Direct mode context examples** (location/portrait focus):
   - "a cozy cafe with warm lighting"
   - "a sunny beach at sunset"
   - "a busy city street at night"
   - "a peaceful park in autumn"

3. **Mode selection**: Let auto-detect work, or explicitly specify for control
4. **Multi-channel**: Pass comma-separated channels for broadcast
5. **Scheduling**: See `SCHEDULE.md` for proactive message setup
6. **Custom image**: Set `REFERENCE_IMAGE_URL` to use a different reference photo

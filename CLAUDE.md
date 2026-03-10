# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Clawgirlfriend** is an npm package and OpenClaw skill installer that adds AI selfie generation to an OpenClaw agent. It uses xAI's Grok Imagine model via fal.ai to edit a fixed reference image and send results to messaging platforms (Discord, Telegram, WhatsApp, etc.) via OpenClaw.

## Commands

```bash
# Run the interactive installer (primary use case)
npx clawgirlfriend@latest

# Run the TypeScript selfie script directly (requires FAL_KEY env var)
npx ts-node skill/scripts/clawgirlfriend-selfie.ts "<prompt>" "<channel>" ["<caption>"]

# Run the bash selfie script directly
FAL_KEY=your_key skill/scripts/clawgirlfriend-selfie.sh "<prompt>" "<channel>" ["<caption>"]
```

There are no build or test scripts. `bin/cli.js` is plain JavaScript (no compilation needed). TypeScript files are executed directly with `ts-node`.

## Architecture

### Installation Flow (`bin/cli.js`)
The CLI runs 7 steps interactively:
1. Checks `openclaw` CLI is installed and `~/.openclaw/` exists
2. Prompts for a fal.ai API key
3. Copies `skill/` → `~/.openclaw/skills/clawgirlfriend-selfie/`
4. Merges skill config into `~/.openclaw/openclaw.json` (sets `FAL_KEY` in skill env)
5. Writes `~/.openclaw/workspace/IDENTITY.md` (agent identity)
6. Appends `templates/soul-injection.md` → `~/.openclaw/workspace/SOUL.md`
7. Prints summary

### Skill (`skill/`)
Once installed to `~/.openclaw/skills/clawgirlfriend-selfie/`, the skill is invoked by the OpenClaw agent:
- `SKILL.md` — skill definition and full instructions for the agent, including prompt templates for two selfie modes
- `scripts/clawgirlfriend-selfie.sh` — bash implementation (uses `curl` + `jq`)
- `scripts/clawgirlfriend-selfie.ts` — TypeScript implementation (uses `@fal-ai/client` or `fetch`)
- `assets/clawra.png` — reference image (also served via jsDelivr CDN)

### Two Selfie Modes
The skill distinguishes between:
- **Mirror mode** (default): `make a pic of this person, but <context>. the person is taking a mirror selfie` — for outfit/fashion shots
- **Direct mode**: `a close-up selfie taken by herself at <context>...` — for location/portrait shots

Mode is auto-detected from keywords in the user's request; the logic is defined in both `SKILL.md` and the scripts.

### Key External APIs
- **fal.ai** (`https://fal.run/xai/grok-imagine-image/edit`) — image editing endpoint; requires `FAL_KEY`
- **OpenClaw Gateway** (`http://localhost:18789/message`) — local messaging gateway; requires `OPENCLAW_GATEWAY_TOKEN`
- **OpenClaw CLI** (`openclaw message send ...`) — alternative to direct API call

### Installed File Locations
| File | Path |
|------|------|
| Skill files | `~/.openclaw/skills/clawgirlfriend-selfie/` |
| OpenClaw config | `~/.openclaw/openclaw.json` |
| Agent identity | `~/.openclaw/workspace/IDENTITY.md` |
| Agent soul/persona | `~/.openclaw/workspace/SOUL.md` |

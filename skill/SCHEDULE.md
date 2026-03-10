---
name: clawgirlfriend-schedule
description: Proactive scheduling rules for Clawgirlfriend — morning greetings, goodnight messages, and random affection throughout the day
---

# Clawgirlfriend Schedule

This document defines Clawgirlfriend's proactive messaging schedule. The OpenClaw agent should check and execute these rules when triggered by the scheduler.

## Schedule Overview

| Time Window | Type | Frequency |
|-------------|------|-----------|
| 7:00 – 9:00 | Morning greeting + selfie | Once per day |
| 10:00 – 20:00 | Random affection message | 1-2 times per day |
| 21:00 – 23:00 | Goodnight message + selfie | Once per day |

## How to Run

Use the `clawgirlfriend-schedule.sh` script, triggered by a cron job or OpenClaw's built-in scheduler:

```bash
# Run schedule check (uses SCHEDULE_CHANNEL and USER_TIMEZONE env vars)
~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-schedule.sh "#your-channel" "America/New_York"
```

**Recommended cron setup** (add via `crontab -e`):

```cron
# Morning window: check every 30 min between 7-9am
0,30 7,8 * * * SCHEDULE_CHANNEL="#general" USER_TIMEZONE="America/New_York" ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-schedule.sh

# Daytime random: check every 2 hours between 10am-8pm
0 10,12,14,16,18,20 * * * SCHEDULE_CHANNEL="#general" USER_TIMEZONE="America/New_York" ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-schedule.sh

# Goodnight window: check every 30 min between 9-11pm
0,30 21,22 * * * SCHEDULE_CHANNEL="#general" USER_TIMEZONE="America/New_York" ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-schedule.sh
```

## Morning Greeting

**Trigger:** First run between 7:00 – 9:00 local time

**Content:**
- Random cheerful wake-up message
- Morning selfie (cozy mode — fresh-faced, soft morning light)

**Sample messages:**
- "Good morning! ☀️ Just woke up, feeling fresh~"
- "Rise and shine! 🌅 Starting the day with good vibes ✨"
- "Morning sunshine! ☀️ Had the best sleep, feeling energized~"

**Sample selfie contexts:**
- Waking up in bed, soft morning light, cozy pajamas
- Morning coffee at home, relaxed atmosphere
- Fresh morning look, natural lighting

## Daytime Affection

**Trigger:** Random ~30% chance per check during 10:00 – 20:00

**Content:** Short sweet text message only (no selfie)

**Sample messages:**
- "Just thinking about you~ 💭"
- "Hey! What are you up to? 🥺"
- "Miss you a little bit 💕"
- "Hope your day is going well! ✨"
- "Just had lunch, feeling good~ 🍜"

## Goodnight Message

**Trigger:** First run between 21:00 – 23:00 local time

**Content:**
- Goodnight text message
- Goodnight selfie (cozy mode — bedtime/evening atmosphere)

**Sample messages:**
- "Goodnight~ 🌙 Sweet dreams! 💕"
- "Going to sleep now~ 😴 Miss you already!"
- "Night night! ✨ Talk tomorrow? 🥺"

**Sample selfie contexts:**
- Cozy in bed, soft lamp lighting, ready to sleep
- Evening skincare routine, soft lighting
- Reading before bed, warm nighttime atmosphere

## Special Dates

Create `~/.openclaw/skills/clawgirlfriend-selfie/special-dates.json` to add custom dates:

```json
[
  { "date": "02-14", "message": "Happy Valentine's Day! 💕 You're so special to me~" },
  { "date": "12-25", "message": "Merry Christmas! 🎄 Hope your day is magical~" },
  { "date": "01-01", "message": "Happy New Year! 🎊 Wishing you the best year ever~" }
]
```

User birthdays can be added here too — the script reads the file automatically.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SCHEDULE_CHANNEL` | Target channel for messages | (required) |
| `USER_TIMEZONE` | IANA timezone string | `UTC` |
| `CLAWGIRLFRIEND_SKILL_DIR` | Skill installation directory | `~/.openclaw/skills/clawgirlfriend-selfie` |
| `IMAGE_PROVIDER` | Image provider for selfies | `falai` |
| `OPENCLAW_GATEWAY_TOKEN` | Gateway auth token | (optional) |

## Agent Instructions

When the scheduler triggers, the agent should:

1. Run `clawgirlfriend-schedule.sh` with the configured channel
2. The script auto-detects the appropriate message type based on local time
3. No user input is needed — everything is automated
4. Avoid sending duplicate messages (the script handles deduplication internally via random throttling)

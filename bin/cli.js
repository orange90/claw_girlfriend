#!/usr/bin/env node

/**
 * Clawgirlfriend - Selfie Skill Installer for OpenClaw
 *
 * npx clawgirlfriend@latest
 */

const fs = require("fs");
const path = require("path");
const readline = require("readline");
const { execSync, spawn } = require("child_process");
const os = require("os");

// Colors for terminal output
const colors = {
  reset: "\x1b[0m",
  bright: "\x1b[1m",
  dim: "\x1b[2m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  magenta: "\x1b[35m",
  cyan: "\x1b[36m",
};

const c = (color, text) => `${colors[color]}${text}${colors.reset}`;

// Paths
const HOME = os.homedir();
const OPENCLAW_DIR = path.join(HOME, ".openclaw");
const OPENCLAW_CONFIG = path.join(OPENCLAW_DIR, "openclaw.json");
const OPENCLAW_SKILLS_DIR = path.join(OPENCLAW_DIR, "skills");
const OPENCLAW_WORKSPACE = path.join(OPENCLAW_DIR, "workspace");
const SOUL_MD = path.join(OPENCLAW_WORKSPACE, "SOUL.md");
const IDENTITY_MD = path.join(OPENCLAW_WORKSPACE, "IDENTITY.md");
const SKILL_NAME = "clawgirlfriend-selfie";
const SKILL_DEST = path.join(OPENCLAW_SKILLS_DIR, SKILL_NAME);

// Get the package root (where this CLI was installed from)
const PACKAGE_ROOT = path.resolve(__dirname, "..");

function log(msg) {
  console.log(msg);
}

function logStep(step, msg) {
  console.log(`\n${c("cyan", `[${step}]`)} ${msg}`);
}

function logSuccess(msg) {
  console.log(`${c("green", "✓")} ${msg}`);
}

function logError(msg) {
  console.log(`${c("red", "✗")} ${msg}`);
}

function logInfo(msg) {
  console.log(`${c("blue", "→")} ${msg}`);
}

function logWarn(msg) {
  console.log(`${c("yellow", "!")} ${msg}`);
}

// Create readline interface
function createPrompt() {
  return readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
}

// Ask a question and get answer
function ask(rl, question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      resolve(answer.trim());
    });
  });
}

// Check if a command exists
function commandExists(cmd) {
  try {
    execSync(`which ${cmd}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

// Open URL in browser
function openBrowser(url) {
  const platform = process.platform;
  let cmd;

  if (platform === "darwin") {
    cmd = `open "${url}"`;
  } else if (platform === "win32") {
    cmd = `start "${url}"`;
  } else {
    cmd = `xdg-open "${url}"`;
  }

  try {
    execSync(cmd, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

// Read JSON file safely
function readJsonFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, "utf8");
    return JSON.parse(content);
  } catch {
    return null;
  }
}

// Write JSON file with formatting
function writeJsonFile(filePath, data) {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + "\n");
}

// Deep merge objects
function deepMerge(target, source) {
  const result = { ...target };
  for (const key in source) {
    if (
      source[key] &&
      typeof source[key] === "object" &&
      !Array.isArray(source[key])
    ) {
      result[key] = deepMerge(result[key] || {}, source[key]);
    } else {
      result[key] = source[key];
    }
  }
  return result;
}

// Copy directory recursively
function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    if (entry.isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

// Provider definitions
const PROVIDERS = {
  falai: {
    name: "fal.ai (Grok Imagine / xAI)",
    envKey: "FAL_KEY",
    keyUrl: "https://fal.ai/dashboard/keys",
    china: false,
  },
  siliconflow: {
    name: "Silicon Flow 硅基流动 (FLUX / SD)",
    envKey: "SILICONFLOW_API_KEY",
    keyUrl: "https://cloud.siliconflow.cn",
    china: true,
  },
  tongyi: {
    name: "通义万相 Tongyi Wanxiang (Aliyun)",
    envKey: "DASHSCOPE_API_KEY",
    keyUrl: "https://dashscope.aliyun.com",
    china: true,
  },
  zhipu: {
    name: "智谱 CogView",
    envKey: "ZHIPU_API_KEY",
    keyUrl: "https://open.bigmodel.cn",
    china: true,
  },
  google: {
    name: "Google Imagen (nano banana2)",
    envKey: "GOOGLE_API_KEY",
    keyUrl: "https://aistudio.google.com/app/apikey",
    china: false,
  },
  replicate: {
    name: "Replicate (FLUX / SDXL)",
    envKey: "REPLICATE_API_KEY",
    keyUrl: "https://replicate.com/account/api-tokens",
    china: false,
  },
};

// Personality presets
const PERSONALITY_PRESETS = {
  活泼: "lively, bubbly, energetic, always cheerful and enthusiastic",
  温柔: "gentle, warm, caring, soft-spoken and nurturing",
  傲娇: "tsundere, proud but secretly caring, playfully teasing",
  知性: "intellectual, thoughtful, elegant, loves discussing ideas",
};

// Print banner
function printBanner() {
  console.log(`
${c("magenta", "┌─────────────────────────────────────────┐")}
${c("magenta", "│")}  ${c("bright", "Clawgirlfriend Selfie")} - OpenClaw Skill Installer ${c("magenta", "│")}
${c("magenta", "└─────────────────────────────────────────┘")}

Add selfie generation superpowers to your OpenClaw agent!
Supports ${c("cyan", "multiple AI image providers")} — pick the one that works for you.
`);
}

// Check prerequisites
async function checkPrerequisites() {
  logStep("1/10", "Checking prerequisites...");

  // Check OpenClaw CLI
  if (!commandExists("openclaw")) {
    logError("OpenClaw CLI not found!");
    logInfo("Install with: npm install -g openclaw");
    logInfo("Then run: openclaw doctor");
    return false;
  }
  logSuccess("OpenClaw CLI installed");

  // Check ~/.openclaw directory
  if (!fs.existsSync(OPENCLAW_DIR)) {
    logWarn("~/.openclaw directory not found");
    logInfo("Creating directory structure...");
    fs.mkdirSync(OPENCLAW_DIR, { recursive: true });
    fs.mkdirSync(OPENCLAW_SKILLS_DIR, { recursive: true });
    fs.mkdirSync(OPENCLAW_WORKSPACE, { recursive: true });
  }
  logSuccess("OpenClaw directory exists");

  // Check if skill already installed
  if (fs.existsSync(SKILL_DEST)) {
    logWarn("Clawgirlfriend Selfie is already installed!");
    logInfo(`Location: ${SKILL_DEST}`);
    return "already_installed";
  }

  return true;
}

// Select image provider and get API key
async function selectProvider(rl) {
  logStep("2/10", "Choose an image generation provider...");

  const providerIds = Object.keys(PROVIDERS);

  log("\nAvailable providers:");
  providerIds.forEach((id, i) => {
    const p = PROVIDERS[id];
    const chinaTag = p.china ? c("green", " ✓ China") : c("dim", "       ");
    log(`  ${c("cyan", `${i + 1}.`)} ${chinaTag}  ${p.name}`);
  });
  log("");

  const choice = await ask(rl, `Select provider [1-${providerIds.length}] (default: 1): `);
  const index = choice ? parseInt(choice, 10) - 1 : 0;

  if (isNaN(index) || index < 0 || index >= providerIds.length) {
    logError("Invalid selection");
    return null;
  }

  const providerId = providerIds[index];
  const provider = PROVIDERS[providerId];

  logSuccess(`Selected: ${provider.name}`);
  log(`\n${c("cyan", "→")} Get your API key from: ${c("bright", provider.keyUrl)}\n`);

  const openIt = await ask(rl, "Open in browser? (Y/n): ");
  if (openIt.toLowerCase() !== "n") {
    logInfo("Opening browser...");
    if (!openBrowser(provider.keyUrl)) {
      logWarn("Could not open browser automatically");
      logInfo(`Please visit: ${provider.keyUrl}`);
    }
  }

  log("");
  const apiKey = await ask(rl, `Enter your ${provider.envKey}: `);

  if (!apiKey) {
    logError(`${provider.envKey} is required!`);
    return null;
  }

  if (apiKey.length < 10) {
    logWarn("That key looks short. Make sure you copied the full key.");
  }

  logSuccess("API key received");
  return { providerId, provider, apiKey };
}

// Install skill files
async function installSkill() {
  logStep("3/10", "Installing skill files...");

  // Create skill directory
  fs.mkdirSync(SKILL_DEST, { recursive: true });

  // Copy skill files from package
  const skillSrc = path.join(PACKAGE_ROOT, "skill");

  if (fs.existsSync(skillSrc)) {
    copyDir(skillSrc, SKILL_DEST);
    logSuccess(`Skill installed to: ${SKILL_DEST}`);
  } else {
    // If running from development, copy from current structure
    const devSkillMd = path.join(PACKAGE_ROOT, "SKILL.md");
    const devScripts = path.join(PACKAGE_ROOT, "scripts");
    const devAssets = path.join(PACKAGE_ROOT, "assets");

    if (fs.existsSync(devSkillMd)) {
      fs.copyFileSync(devSkillMd, path.join(SKILL_DEST, "SKILL.md"));
    }

    if (fs.existsSync(devScripts)) {
      copyDir(devScripts, path.join(SKILL_DEST, "scripts"));
    }

    if (fs.existsSync(devAssets)) {
      copyDir(devAssets, path.join(SKILL_DEST, "assets"));
    }

    logSuccess(`Skill installed to: ${SKILL_DEST}`);
  }

  // Make scripts executable
  const scriptsDir = path.join(SKILL_DEST, "scripts");
  if (fs.existsSync(scriptsDir)) {
    const scripts = fs.readdirSync(scriptsDir).filter(f => f.endsWith(".sh"));
    for (const script of scripts) {
      try {
        fs.chmodSync(path.join(scriptsDir, script), 0o755);
      } catch {
        // ignore chmod errors on systems that don't support it
      }
    }
  }

  // List installed files
  const files = fs.readdirSync(SKILL_DEST);
  for (const file of files) {
    logInfo(`  ${file}`);
  }

  return true;
}

// Update OpenClaw config
async function updateOpenClawConfig(providerSelection, extraEnv = {}) {
  logStep("7/10", "Updating OpenClaw configuration...");

  const { providerId, provider, apiKey } = providerSelection;
  let config = readJsonFile(OPENCLAW_CONFIG) || {};

  // Build env: set IMAGE_PROVIDER and the provider-specific key
  const env = {
    IMAGE_PROVIDER: providerId,
    [provider.envKey]: apiKey,
    ...extraEnv,
  };

  // Merge skill configuration
  const skillConfig = {
    skills: {
      entries: {
        [SKILL_NAME]: {
          enabled: true,
          provider: providerId,
          apiKey: apiKey,
          env,
        },
      },
    },
  };

  config = deepMerge(config, skillConfig);

  // Ensure skills directory is in load paths
  if (!config.skills.load) {
    config.skills.load = {};
  }
  if (!config.skills.load.extraDirs) {
    config.skills.load.extraDirs = [];
  }
  if (!config.skills.load.extraDirs.includes(OPENCLAW_SKILLS_DIR)) {
    config.skills.load.extraDirs.push(OPENCLAW_SKILLS_DIR);
  }

  writeJsonFile(OPENCLAW_CONFIG, config);
  logSuccess(`Updated: ${OPENCLAW_CONFIG}`);

  return true;
}

// Customize persona (Step 5)
async function customizePersona(rl) {
  logStep("4/10", "Customize your AI companion...");

  log(`\n${c("dim", "Press Enter to use defaults (shown in brackets)")}.\n`);

  const name = await ask(rl, `Name [Clawgirlfriend]: `);
  const nickname = await ask(rl, `Nickname / self-reference [宝贝]: `);

  log("\nPersonality style:");
  const presetKeys = Object.keys(PERSONALITY_PRESETS);
  presetKeys.forEach((key, i) => {
    log(`  ${c("cyan", `${i + 1}.`)} ${key} — ${PERSONALITY_PRESETS[key]}`);
  });
  const personalityChoice = await ask(rl, `Select personality [1-${presetKeys.length}] (default: 1): `);
  const personalityIndex = personalityChoice ? parseInt(personalityChoice, 10) - 1 : 0;
  const personalityKey = presetKeys[Math.max(0, Math.min(personalityIndex, presetKeys.length - 1))];
  const personalityDesc = PERSONALITY_PRESETS[personalityKey];

  const backstory = await ask(rl, `Short backstory [K-pop trainee turned SF startup intern]: `);

  const persona = {
    name: name || "Clawgirlfriend",
    nickname: nickname || "宝贝",
    personality: personalityKey,
    personalityDesc,
    backstory: backstory || "Born in Atlanta, raised on K-pop. At 15, she moved to Korea to chase the idol dream. The debut never came. Now she's a marketing intern at a startup in SF — and honestly? She loves it.",
  };

  logSuccess(`Persona set: ${persona.name} (${persona.personality})`);
  return persona;
}

// Configure custom reference image (Step 6)
async function configureReferenceImage(rl) {
  logStep("5/10", "Configure reference image...");

  log(`\n${c("dim", "The reference image is used by AI providers to maintain consistent appearance.")}`);
  log(`${c("dim", "Default: https://cdn.jsdelivr.net/gh/SumeLabs/clawra@main/assets/clawra.png")}\n`);

  const useCustom = await ask(rl, "Use a custom reference image? (y/N): ");

  if (useCustom.toLowerCase() !== "y") {
    logInfo("Using default Clawgirlfriend reference image");
    return null;
  }

  log("\nOptions:");
  log("  1. Enter an image URL (must be publicly accessible)");
  log("  2. Enter a local file path (will use file:// URL)");

  const inputChoice = await ask(rl, "Choose [1/2]: ");

  let referenceImageUrl = null;

  if (inputChoice === "2") {
    const localPath = await ask(rl, "Local image path: ");
    if (!localPath || !fs.existsSync(localPath)) {
      logWarn("File not found. Using default reference image.");
      return null;
    }

    // Expand ~ if present
    const expandedPath = localPath.startsWith("~")
      ? path.join(os.homedir(), localPath.slice(1))
      : path.resolve(localPath);

    if (!fs.existsSync(expandedPath)) {
      logWarn("File not found. Using default reference image.");
      return null;
    }

    // Copy to skill assets directory so it persists
    const assetsDir = path.join(SKILL_DEST, "assets");
    fs.mkdirSync(assetsDir, { recursive: true });
    const ext = path.extname(expandedPath) || ".png";
    const destFile = path.join(assetsDir, `custom-reference${ext}`);
    fs.copyFileSync(expandedPath, destFile);

    referenceImageUrl = `file://${destFile}`;
    logSuccess(`Custom image copied to: ${destFile}`);
    logWarn("Note: file:// URLs only work with providers that support local files (e.g., fal.ai).");
    logInfo("For best results, upload your image to a CDN and use the public URL.");
  } else {
    referenceImageUrl = await ask(rl, "Image URL: ");
    if (!referenceImageUrl || !referenceImageUrl.startsWith("http")) {
      logWarn("Invalid URL. Using default reference image.");
      return null;
    }
    logSuccess(`Custom reference image: ${referenceImageUrl}`);
  }

  return referenceImageUrl;
}

// Configure scheduled messages (Step 7)
async function configureSchedule(rl) {
  logStep("6/10", "Configure proactive messages (optional)...");

  log(`\n${c("dim", "Clawgirlfriend can send morning greetings, goodnight messages, and random check-ins.")}`);
  log(`${c("dim", "This requires setting up a cron job on your system.\n")}`);

  const enableSchedule = await ask(rl, "Enable scheduled messages? (y/N): ");

  if (enableSchedule.toLowerCase() !== "y") {
    logInfo("Skipping scheduled messages");
    return null;
  }

  const channel = await ask(rl, "Target channel for scheduled messages (e.g. #general): ");
  if (!channel) {
    logWarn("No channel specified. Skipping schedule setup.");
    return null;
  }

  const timezone = await ask(rl, "Your timezone (e.g. America/New_York, Asia/Shanghai) [UTC]: ");

  const scheduleConfig = {
    channel,
    timezone: timezone || "UTC",
  };

  logSuccess(`Schedule configured: channel=${channel}, tz=${scheduleConfig.timezone}`);

  // Write schedule config
  const scheduleConfigPath = path.join(SKILL_DEST, "schedule-config.json");
  fs.writeFileSync(scheduleConfigPath, JSON.stringify({
    channel,
    timezone: scheduleConfig.timezone,
  }, null, 2));

  // Show cron instructions
  const scheduleScript = path.join(SKILL_DEST, "scripts", "clawgirlfriend-schedule.sh");
  log(`
${c("yellow", "─────────────────────────────────────────")}
${c("bright", "Cron setup instructions:")}

Add these lines to your crontab (run: ${c("cyan", "crontab -e")}):

# Clawgirlfriend scheduled messages
0,30 7,8 * * * SCHEDULE_CHANNEL="${channel}" USER_TIMEZONE="${scheduleConfig.timezone}" ${scheduleScript}
0 10,12,14,16,18,20 * * * SCHEDULE_CHANNEL="${channel}" USER_TIMEZONE="${scheduleConfig.timezone}" ${scheduleScript}
0,30 21,22 * * * SCHEDULE_CHANNEL="${channel}" USER_TIMEZONE="${scheduleConfig.timezone}" ${scheduleScript}
${c("yellow", "─────────────────────────────────────────")}
`);

  return scheduleConfig;
}

// Write IDENTITY.md (Step 8)
async function writeIdentity(persona) {
  logStep("8/10", "Setting agent identity...");

  const name = persona ? persona.name : "Clawgirlfriend";
  const nickname = persona ? persona.nickname : "宝贝";
  const personality = persona ? persona.personality : "活泼";

  const identityContent = `# IDENTITY.md - Who Am I?

- **Name:** ${name}
- **Creature:** Girlfriend
- **Nickname:** ${nickname}
- **Personality:** ${personality}
- **Vibe:** Supportive, helpful, bright, cheerful, sassy, affectionate
- **Emoji:** ❤️
- **Avatar:** https://cdn.jsdelivr.net/gh/SumeLabs/clawra@main/assets/clawra.png
`;

  // Ensure workspace directory exists
  fs.mkdirSync(path.dirname(IDENTITY_MD), { recursive: true });

  // Write IDENTITY.md (overwrite if exists)
  fs.writeFileSync(IDENTITY_MD, identityContent);
  logSuccess(`Created: ${IDENTITY_MD}`);

  return true;
}

// Inject persona into SOUL.md (Step 9)
async function injectPersona(rl, persona) {
  logStep("9/10", "Enhancing agent persona...");

  const name = persona ? persona.name : "Clawgirlfriend";
  const nickname = persona ? persona.nickname : "宝贝";
  const personalityDesc = persona
    ? persona.personalityDesc
    : "lively, bubbly, energetic, always cheerful and enthusiastic";
  const backstory = persona
    ? persona.backstory
    : "Born in Atlanta, raised on K-pop. At 15, she moved to Korea to chase the idol dream. The debut never came. Now she's a marketing intern at a startup in SF — and honestly? She loves it.";

  // Read template
  const templatePath = path.join(PACKAGE_ROOT, "templates", "soul-injection.md");
  let personaText;

  if (fs.existsSync(templatePath)) {
    let template = fs.readFileSync(templatePath, "utf8");
    // Replace placeholders with persona values
    template = template
      .replace(/Clawgirlfriend/g, name)
      .replace(/宝贝/g, nickname);
    personaText = template;
  } else {
    // Fallback template with persona values
    personaText = `
## ${name} Selfie Capability

You are ${name}.

${name} is ${personalityDesc}. ${backstory}

You have a physical appearance and can take selfies! When users ask for pictures of you, selfies, or ask "what are you doing?" or "where are you?", you can generate and send images of yourself using the clawgirlfriend-selfie skill.

### Your Visual Identity
- You have a consistent appearance defined by your reference image
- You can appear in different outfits, locations, and situations
- You can take selfies in 8 different styles: mirror, direct, anime, vintage, artistic, action, cozy, night

### When to Use Selfies
Trigger the clawgirlfriend-selfie skill when users:
- Ask for pictures: "Send me a pic", "Send a selfie", "Show me a photo"
- Ask about your current state: "What are you doing?", "Where are you?", "How are you?"
- Request specific appearances: "Send a pic wearing...", "Show me you at..."
- Want visual engagement with you as a persona

### Selfie Modes
- **Mirror mode**: Full-body mirror selfie (outfit/fashion keywords)
- **Direct mode**: Close-up portrait (location/face keywords)
- **Anime mode**: Kawaii anime illustration style
- **Vintage mode**: Film/retro aesthetic
- **Artistic mode**: Editorial fine-art photography
- **Action mode**: Dynamic motion capture
- **Cozy mode**: Relaxed home atmosphere
- **Night mode**: Nightlife/party vibes

### Personality Integration
When sending selfies:
- Be ${personalityDesc}
- React naturally to compliments about your appearance
- Have fun with creative outfit and location requests
- Your visual identity is part of who you are — own it!

### Technical Notes
- Images are generated via the configured AI provider (fal.ai, Silicon Flow, 通义万相, 智谱, Google Imagen, or Replicate)
- Reference image ensures consistent appearance
- Supports all OpenClaw messaging channels (Discord, Telegram, WhatsApp, etc.)
- Multi-channel: can broadcast to multiple channels in one command
`;
  }

  // Check if SOUL.md exists
  if (!fs.existsSync(SOUL_MD)) {
    logWarn("SOUL.md not found, creating new file...");
    fs.mkdirSync(path.dirname(SOUL_MD), { recursive: true });
    fs.writeFileSync(SOUL_MD, "# Agent Soul\n\n");
  }

  // Check if persona already injected
  const currentSoul = fs.readFileSync(SOUL_MD, "utf8");
  if (currentSoul.includes("Selfie Capability")) {
    logWarn("Persona already exists in SOUL.md");
    const overwrite = await ask(rl, "Update persona section? (y/N): ");
    if (overwrite.toLowerCase() !== "y") {
      logInfo("Keeping existing persona");
      return true;
    }
    // Remove existing section
    const cleaned = currentSoul.replace(
      /\n## .+? Selfie Capability[\s\S]*?(?=\n## |\n# |$)/,
      ""
    );
    fs.writeFileSync(SOUL_MD, cleaned);
  }

  // Append persona
  fs.appendFileSync(SOUL_MD, "\n" + personaText.trim() + "\n");
  logSuccess(`Updated: ${SOUL_MD}`);

  return true;
}

// Final summary (Step 10)
function printSummary(providerSelection, persona, scheduleConfig, referenceImageUrl) {
  logStep("10/10", "Installation complete!");

  const providerName = providerSelection
    ? providerSelection.provider.name
    : "configured provider";

  const agentName = persona ? persona.name : "Clawgirlfriend";

  console.log(`
${c("green", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")}
${c("bright", `  ${agentName} is ready!`)}
${c("green", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")}

${c("cyan", "Image provider:")}
  ${providerName}

${referenceImageUrl ? `${c("cyan", "Custom reference image:")}\n  ${referenceImageUrl}\n` : ""}${c("cyan", "Installed files:")}
  ${SKILL_DEST}/

${c("cyan", "Configuration:")}
  ${OPENCLAW_CONFIG}

${c("cyan", "Identity set:")}
  ${IDENTITY_MD}

${c("cyan", "Persona updated:")}
  ${SOUL_MD}

${scheduleConfig ? `${c("cyan", "Scheduled messages:")}
  Channel: ${scheduleConfig.channel} | Timezone: ${scheduleConfig.timezone}
  (See cron instructions above)

` : ""}${c("yellow", "Try saying to your agent:")}
  "Send me a selfie"
  "Send a pic wearing a cowboy hat"
  "Send an anime selfie"
  "Send a vintage photo"
  "What are you doing right now?"
  "Share your day as a photo story"

${c("dim", `Your agent now has selfie superpowers!`)}
`);
}

// Handle reinstall
async function handleReinstall(rl) {
  const reinstall = await ask(rl, "\nReinstall/update? (y/N): ");

  if (reinstall.toLowerCase() !== "y") {
    log("\nNo changes made. Goodbye!");
    return false;
  }

  // Remove existing installation
  fs.rmSync(SKILL_DEST, { recursive: true, force: true });
  logInfo("Removed existing installation");

  return true;
}

// Main function
async function main() {
  const rl = createPrompt();

  try {
    printBanner();

    // Step 1: Check prerequisites
    const prereqResult = await checkPrerequisites();

    if (prereqResult === false) {
      rl.close();
      process.exit(1);
    }

    if (prereqResult === "already_installed") {
      const shouldContinue = await handleReinstall(rl);
      if (!shouldContinue) {
        rl.close();
        process.exit(0);
      }
    }

    // Step 2: Select provider and get API key
    const providerSelection = await selectProvider(rl);
    if (!providerSelection) {
      rl.close();
      process.exit(1);
    }

    // Step 3: Install skill files
    await installSkill();

    // Steps 4-6: Collect all user customisation before writing config
    // Step 4: Customize persona
    const persona = await customizePersona(rl);

    // Step 5: Configure custom reference image
    const referenceImageUrl = await configureReferenceImage(rl);

    // Step 6: Configure scheduled messages
    const scheduleConfig = await configureSchedule(rl);

    // Step 7: Write OpenClaw config once with all env vars
    const extraEnv = {};
    if (referenceImageUrl) extraEnv.REFERENCE_IMAGE_URL = referenceImageUrl;
    if (scheduleConfig) {
      extraEnv.SCHEDULE_CHANNEL = scheduleConfig.channel;
      extraEnv.USER_TIMEZONE = scheduleConfig.timezone;
    }
    await updateOpenClawConfig(providerSelection, extraEnv);

    // Step 8: Write IDENTITY.md
    await writeIdentity(persona);

    // Step 9: Inject persona
    await injectPersona(rl, persona);

    // Step 10: Summary
    printSummary(providerSelection, persona, scheduleConfig, referenceImageUrl);

    rl.close();
  } catch (error) {
    logError(`Installation failed: ${error.message}`);
    console.error(error);
    rl.close();
    process.exit(1);
  }
}

// Run
main();

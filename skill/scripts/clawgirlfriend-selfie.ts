/**
 * Clawgirlfriend Selfie - Multi-Provider Image Generation
 *
 * Generates/edits images using various AI providers
 * and sends them to messaging channels via OpenClaw.
 *
 * Usage:
 *   npx ts-node clawgirlfriend-selfie.ts "<prompt>" "<channel>" ["<caption>"] ["<mode>"]
 *
 * Environment variables:
 *   IMAGE_PROVIDER          - Provider: falai | siliconflow | tongyi | zhipu | google | replicate
 *                             (default: falai)
 *   REFERENCE_IMAGE_URL     - Override default reference image URL
 *   FAL_KEY                 - fal.ai API key (https://fal.ai/dashboard/keys)
 *   SILICONFLOW_API_KEY     - Silicon Flow key (https://cloud.siliconflow.cn)
 *   DASHSCOPE_API_KEY       - 通义万相/Aliyun key (https://dashscope.aliyun.com)
 *   ZHIPU_API_KEY           - 智谱 CogView key (https://open.bigmodel.cn)
 *   GOOGLE_API_KEY          - Google Imagen key (https://aistudio.google.com/app/apikey)
 *   REPLICATE_API_KEY       - Replicate key (https://replicate.com/account/api-tokens)
 *   SILICONFLOW_MODEL       - SiliconFlow model (default: black-forest-labs/FLUX.1-schnell)
 *   TONGYI_MODEL            - Tongyi model (default: wanx2.1-t2i-turbo)
 *   ZHIPU_MODEL             - Zhipu model (default: cogview-4)
 *   GOOGLE_MODEL            - Google model (default: imagen-3.0-fast-generate-001)
 *   REPLICATE_MODEL         - Replicate model (default: black-forest-labs/flux-schnell)
 *   OPENCLAW_GATEWAY_URL    - OpenClaw gateway (default: http://localhost:18789)
 *   OPENCLAW_GATEWAY_TOKEN  - Gateway auth token (optional)
 */

import { exec } from "child_process";
import { promisify } from "util";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const execAsync = promisify(exec);

// Reference image for providers that support image editing
const REFERENCE_IMAGE =
  process.env.REFERENCE_IMAGE_URL ||
  "https://cdn.jsdelivr.net/gh/SumeLabs/clawra@main/assets/clawra.png";

// Supported providers
type ImageProvider =
  | "falai"
  | "siliconflow"
  | "tongyi"
  | "zhipu"
  | "google"
  | "replicate";

// Supported selfie modes
type SelfieMode =
  | "mirror"
  | "direct"
  | "anime"
  | "vintage"
  | "artistic"
  | "action"
  | "cozy"
  | "night"
  | "auto";

interface ProviderInfo {
  name: string;
  envKey: string;
  keyUrl: string;
  supportsEdit: boolean;
  chinaAccessible: boolean;
}

const PROVIDER_INFO: Record<ImageProvider, ProviderInfo> = {
  falai: {
    name: "fal.ai (Grok Imagine / xAI)",
    envKey: "FAL_KEY",
    keyUrl: "https://fal.ai/dashboard/keys",
    supportsEdit: true,
    chinaAccessible: false,
  },
  siliconflow: {
    name: "Silicon Flow 硅基流动 (FLUX / SD)",
    envKey: "SILICONFLOW_API_KEY",
    keyUrl: "https://cloud.siliconflow.cn",
    supportsEdit: false,
    chinaAccessible: true,
  },
  tongyi: {
    name: "通义万相 Tongyi Wanxiang (Aliyun)",
    envKey: "DASHSCOPE_API_KEY",
    keyUrl: "https://dashscope.aliyun.com",
    supportsEdit: true,
    chinaAccessible: true,
  },
  zhipu: {
    name: "智谱 CogView",
    envKey: "ZHIPU_API_KEY",
    keyUrl: "https://open.bigmodel.cn",
    supportsEdit: false,
    chinaAccessible: true,
  },
  google: {
    name: "Google Imagen (nano banana2)",
    envKey: "GOOGLE_API_KEY",
    keyUrl: "https://aistudio.google.com/app/apikey",
    supportsEdit: false,
    chinaAccessible: false,
  },
  replicate: {
    name: "Replicate (FLUX / SDXL)",
    envKey: "REPLICATE_API_KEY",
    keyUrl: "https://replicate.com/account/api-tokens",
    supportsEdit: false,
    chinaAccessible: false,
  },
};

// Mode keyword patterns
const MODE_PATTERNS: Array<{ mode: SelfieMode; pattern: RegExp }> = [
  { mode: "anime", pattern: /anime|cartoon|drawn|illustrated|2d|chibi|manga/i },
  { mode: "vintage", pattern: /vintage|film|retro|90s|polaroid|grainy|kodak/i },
  { mode: "artistic", pattern: /artistic|art|painting|aesthetic|editorial|fine art/i },
  { mode: "action", pattern: /dancing|running|jumping|action|moving|spinning|workout/i },
  { mode: "cozy", pattern: /home|pajamas|morning|cozy|bed|blanket|indoor|waking/i },
  { mode: "night", pattern: /night out|party|club|neon|bar|nightlife|evening out/i },
  { mode: "mirror", pattern: /outfit|wearing|clothes|dress|suit|fashion|full-body|mirror/i },
  { mode: "direct", pattern: /cafe|restaurant|beach|park|city|location|portrait|face|eyes|smile/i },
];

interface OpenClawMessage {
  action: "send";
  channel: string;
  message: string;
  media?: string;
}

interface GenerateAndSendOptions {
  prompt: string;
  channel: string;
  caption?: string;
  mode?: SelfieMode;
  useClaudeCodeCLI?: boolean;
}

interface Result {
  success: boolean;
  imageUrl: string;
  channels: string[];
  prompt: string;
  provider: string;
  mode: string;
}

// ─── Mode detection ───────────────────────────────────────────────────────────

export function detectMode(context: string): Exclude<SelfieMode, "auto"> {
  for (const { mode, pattern } of MODE_PATTERNS) {
    if (pattern.test(context)) {
      return mode as Exclude<SelfieMode, "auto">;
    }
  }
  return "mirror"; // default
}

// ─── Prompt builder ───────────────────────────────────────────────────────────

export function buildPrompt(context: string, mode: Exclude<SelfieMode, "auto">): string {
  switch (mode) {
    case "mirror":
      return `make a pic of this person, but ${context}. the person is taking a mirror selfie`;
    case "direct":
      return `a close-up selfie taken by herself at ${context}, direct eye contact with the camera, looking straight into the lens, eyes centered and clearly visible, not a mirror selfie, phone held at arm's length, face fully visible`;
    case "anime":
      return `anime illustration style portrait of this person, ${context}, vibrant colors, clean linework, expressive eyes, kawaii aesthetic, manga-inspired`;
    case "vintage":
      return `vintage film photograph of this person, ${context}, grainy film texture, warm tones, retro color grading, kodachrome aesthetic, slightly faded edges`;
    case "artistic":
      return `fine art photography portrait of this person, ${context}, editorial style, dramatic lighting, artistic composition, high fashion aesthetic`;
    case "action":
      return `dynamic action shot of this person, ${context}, motion blur, energetic pose, candid movement, high shutter speed feel`;
    case "cozy":
      return `cozy casual photo of this person, ${context}, soft natural lighting, relaxed atmosphere, warm home environment, candid and natural`;
    case "night":
      return `nighttime photo of this person, ${context}, neon lights bokeh, dramatic shadows, vibrant nightlife atmosphere, moody evening lighting`;
  }
}

// ─── Provider: fal.ai ────────────────────────────────────────────────────────

async function generateWithFalai(
  prompt: string,
  referenceImageUrl?: string
): Promise<string> {
  const apiKey = process.env.FAL_KEY;
  if (!apiKey) {
    throw new Error(
      "FAL_KEY not set. Get your key: https://fal.ai/dashboard/keys"
    );
  }

  let endpoint: string;
  let body: Record<string, unknown>;

  if (referenceImageUrl) {
    endpoint = "https://fal.run/xai/grok-imagine-image/edit";
    body = {
      image_url: referenceImageUrl,
      prompt,
      num_images: 1,
      output_format: "jpeg",
    };
  } else {
    endpoint = "https://fal.run/xai/grok-imagine-image";
    body = { prompt, num_images: 1, output_format: "jpeg" };
  }

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Key ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`fal.ai error (${response.status}): ${err}`);
  }

  const data = (await response.json()) as { images: Array<{ url: string }> };
  return data.images[0].url;
}

// ─── Provider: Silicon Flow ───────────────────────────────────────────────────

async function generateWithSiliconFlow(prompt: string): Promise<string> {
  const apiKey = process.env.SILICONFLOW_API_KEY;
  if (!apiKey) {
    throw new Error(
      "SILICONFLOW_API_KEY not set. Get your key: https://cloud.siliconflow.cn"
    );
  }

  const model =
    process.env.SILICONFLOW_MODEL || "black-forest-labs/FLUX.1-schnell";

  const response = await fetch(
    "https://api.siliconflow.cn/v1/images/generations",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        prompt,
        image_size: "1024x1024",
        num_inference_steps: 20,
        num_images: 1,
      }),
    }
  );

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`SiliconFlow error (${response.status}): ${err}`);
  }

  const data = (await response.json()) as { images: Array<{ url: string }> };
  return data.images[0].url;
}

// ─── Provider: 通义万相 (Aliyun DashScope) ────────────────────────────────────

async function generateWithTongyi(prompt: string): Promise<string> {
  const apiKey = process.env.DASHSCOPE_API_KEY;
  if (!apiKey) {
    throw new Error(
      "DASHSCOPE_API_KEY not set. Get your key: https://dashscope.aliyun.com"
    );
  }

  const model = process.env.TONGYI_MODEL || "wanx2.1-t2i-turbo";

  // Submit async task
  const submitResponse = await fetch(
    "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "X-DashScope-Async": "enable",
      },
      body: JSON.stringify({
        model,
        input: { prompt },
        parameters: { size: "1024*1024", n: 1 },
      }),
    }
  );

  if (!submitResponse.ok) {
    const err = await submitResponse.text();
    throw new Error(`通义万相 submit error (${submitResponse.status}): ${err}`);
  }

  const submitData = (await submitResponse.json()) as {
    output: { task_id: string };
  };
  const taskId = submitData.output.task_id;
  console.log(`[INFO] 通义万相 task submitted: ${taskId}`);

  // Poll for result (up to 90 seconds)
  for (let i = 0; i < 30; i++) {
    await new Promise((r) => setTimeout(r, 3000));

    const pollResponse = await fetch(
      `https://dashscope.aliyuncs.com/api/v1/tasks/${taskId}`,
      { headers: { Authorization: `Bearer ${apiKey}` } }
    );

    const pollData = (await pollResponse.json()) as {
      output: {
        task_status: string;
        results?: Array<{ url: string }>;
        message?: string;
      };
    };

    const status = pollData.output.task_status;
    console.log(`[INFO] Task status: ${status}`);

    if (status === "SUCCEEDED") {
      return pollData.output.results![0].url;
    }
    if (status === "FAILED") {
      throw new Error(
        `通义万相 task failed: ${pollData.output.message || "unknown"}`
      );
    }
  }

  throw new Error("通义万相 task timed out after 90 seconds");
}

// ─── Provider: 智谱 CogView ───────────────────────────────────────────────────

async function generateWithZhipu(prompt: string): Promise<string> {
  const apiKey = process.env.ZHIPU_API_KEY;
  if (!apiKey) {
    throw new Error(
      "ZHIPU_API_KEY not set. Get your key: https://open.bigmodel.cn"
    );
  }

  const model = process.env.ZHIPU_MODEL || "cogview-4";

  const response = await fetch(
    "https://open.bigmodel.cn/api/paas/v4/images/generations",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ model, prompt, size: "1024x1024" }),
    }
  );

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`智谱 CogView error (${response.status}): ${err}`);
  }

  const data = (await response.json()) as { data: Array<{ url: string }> };
  return data.data[0].url;
}

// ─── Provider: Google Imagen (nano banana2) ───────────────────────────────────

async function generateWithGoogle(prompt: string): Promise<string> {
  const apiKey = process.env.GOOGLE_API_KEY;
  if (!apiKey) {
    throw new Error(
      "GOOGLE_API_KEY not set. Get your key: https://aistudio.google.com/app/apikey"
    );
  }

  const model = process.env.GOOGLE_MODEL || "imagen-3.0-fast-generate-001";

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:predict?key=${apiKey}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        instances: [{ prompt }],
        parameters: { sampleCount: 1 },
      }),
    }
  );

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Google Imagen error (${response.status}): ${err}`);
  }

  const data = (await response.json()) as {
    predictions: Array<{ bytesBase64Encoded: string; mimeType: string }>;
  };

  // Google returns base64 — write to temp file
  const base64 = data.predictions[0].bytesBase64Encoded;
  const mimeType = data.predictions[0].mimeType || "image/jpeg";
  const ext = mimeType.includes("png") ? "png" : "jpeg";
  const tmpFile = path.join(os.tmpdir(), `clawgirlfriend-selfie-${Date.now()}.${ext}`);

  fs.writeFileSync(tmpFile, Buffer.from(base64, "base64"));
  console.log(`[INFO] Google Imagen: image saved to ${tmpFile}`);

  return tmpFile;
}

// ─── Provider: Replicate ──────────────────────────────────────────────────────

async function generateWithReplicate(prompt: string): Promise<string> {
  const apiKey = process.env.REPLICATE_API_KEY;
  if (!apiKey) {
    throw new Error(
      "REPLICATE_API_KEY not set. Get your key: https://replicate.com/account/api-tokens"
    );
  }

  const model =
    process.env.REPLICATE_MODEL || "black-forest-labs/flux-schnell";

  const createResponse = await fetch(
    `https://api.replicate.com/v1/models/${model}/predictions`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        Prefer: "wait",
      },
      body: JSON.stringify({ input: { prompt, num_outputs: 1 } }),
    }
  );

  if (!createResponse.ok) {
    const err = await createResponse.text();
    throw new Error(`Replicate error (${createResponse.status}): ${err}`);
  }

  const createData = (await createResponse.json()) as {
    id: string;
    status: string;
    output?: string[];
    urls: { get: string };
  };

  if (createData.status === "succeeded" && createData.output) {
    return createData.output[0];
  }

  // Poll for result (up to 60 seconds)
  for (let i = 0; i < 30; i++) {
    await new Promise((r) => setTimeout(r, 2000));

    const pollResponse = await fetch(createData.urls.get, {
      headers: { Authorization: `Bearer ${apiKey}` },
    });

    const pollData = (await pollResponse.json()) as {
      status: string;
      output?: string[];
      error?: string;
    };

    console.log(`[INFO] Replicate status: ${pollData.status}`);

    if (pollData.status === "succeeded") {
      return pollData.output![0];
    }
    if (pollData.status === "failed") {
      throw new Error(`Replicate failed: ${pollData.error || "unknown"}`);
    }
  }

  throw new Error("Replicate timed out after 60 seconds");
}

// ─── Main dispatcher ──────────────────────────────────────────────────────────

function getProvider(): ImageProvider {
  const raw = (process.env.IMAGE_PROVIDER || "falai").toLowerCase();
  const valid: ImageProvider[] = [
    "falai",
    "siliconflow",
    "tongyi",
    "zhipu",
    "google",
    "replicate",
  ];
  if (!valid.includes(raw as ImageProvider)) {
    throw new Error(
      `Unknown IMAGE_PROVIDER: "${raw}". Valid options: ${valid.join(", ")}`
    );
  }
  return raw as ImageProvider;
}

async function generateImage(
  prompt: string,
  useReferenceImage: boolean = true
): Promise<string> {
  const provider = getProvider();
  const info = PROVIDER_INFO[provider];
  console.log(`[INFO] Provider: ${info.name}`);

  const refImage = useReferenceImage ? REFERENCE_IMAGE : undefined;

  switch (provider) {
    case "falai":
      return generateWithFalai(prompt, refImage);
    case "siliconflow":
      return generateWithSiliconFlow(prompt);
    case "tongyi":
      return generateWithTongyi(prompt);
    case "zhipu":
      return generateWithZhipu(prompt);
    case "google":
      return generateWithGoogle(prompt);
    case "replicate":
      return generateWithReplicate(prompt);
  }
}

// ─── OpenClaw sender ──────────────────────────────────────────────────────────

async function sendViaOpenClaw(
  message: OpenClawMessage,
  useCLI: boolean = true
): Promise<void> {
  if (useCLI) {
    const cmd = `openclaw message send --action send --channel "${message.channel}" --message "${message.message}" --media "${message.media}"`;
    await execAsync(cmd);
    return;
  }

  const gatewayUrl =
    process.env.OPENCLAW_GATEWAY_URL || "http://localhost:18789";
  const gatewayToken = process.env.OPENCLAW_GATEWAY_TOKEN;

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (gatewayToken) {
    headers["Authorization"] = `Bearer ${gatewayToken}`;
  }

  const response = await fetch(`${gatewayUrl}/message`, {
    method: "POST",
    headers,
    body: JSON.stringify(message),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenClaw send failed: ${error}`);
  }
}

// ─── Orchestrator ─────────────────────────────────────────────────────────────

async function generateAndSend(
  options: GenerateAndSendOptions
): Promise<Result> {
  const {
    prompt,
    channel,
    caption = "✨",
    mode = "auto",
    useClaudeCodeCLI = true,
  } = options;

  // Resolve mode and build prompt
  const resolvedMode = mode === "auto" ? detectMode(prompt) : mode;
  console.log(`[INFO] Mode: ${resolvedMode}`);

  // Check if prompt is already a full constructed prompt or raw user context
  const isRawContext = !/^(make a pic|a close-up selfie|anime illustration|vintage film|fine art|dynamic action|cozy casual|nighttime photo)/i.test(prompt);
  const finalPrompt = isRawContext ? buildPrompt(prompt, resolvedMode) : prompt;

  console.log(`[INFO] Generating image...`);
  console.log(`[INFO] Prompt: ${finalPrompt}`);

  const imageUrl = await generateImage(finalPrompt, true);
  console.log(`[INFO] Image ready: ${imageUrl}`);

  // Support comma-separated multi-channel broadcast
  const channels = channel.split(",").map((ch) => ch.trim()).filter(Boolean);

  for (const ch of channels) {
    console.log(`[INFO] Sending to channel: ${ch}`);
    await sendViaOpenClaw(
      { action: "send", channel: ch, message: caption, media: imageUrl },
      useClaudeCodeCLI
    );
  }

  console.log(`[INFO] Done!`);

  return {
    success: true,
    imageUrl,
    channels,
    prompt: finalPrompt,
    provider: getProvider(),
    mode: resolvedMode,
  };
}

// ─── CLI entry point ──────────────────────────────────────────────────────────

async function main() {
  const args = process.argv.slice(2);

  if (args.length < 2) {
    const providerList = Object.entries(PROVIDER_INFO)
      .map(
        ([id, info]) =>
          `    ${id.padEnd(14)} ${info.name}${info.chinaAccessible ? " ✓中国可用" : ""}`
      )
      .join("\n");

    console.log(`
Usage: npx ts-node clawgirlfriend-selfie.ts <prompt> <channel> [caption] [mode]

Arguments:
  prompt   - Image description / user context (required)
  channel  - Target channel(s), comma-separated (required) e.g., #general,@user
  caption  - Message caption (default: ✨)
  mode     - Selfie mode: mirror|direct|anime|vintage|artistic|action|cozy|night|auto (default: auto)

Providers (set IMAGE_PROVIDER env var):
${providerList}

Environment:
  IMAGE_PROVIDER      - Which provider to use (default: falai)
  REFERENCE_IMAGE_URL - Override default reference image URL
  FAL_KEY             - fal.ai API key
  SILICONFLOW_API_KEY - Silicon Flow API key
  DASHSCOPE_API_KEY   - 通义万相 API key
  ZHIPU_API_KEY       - 智谱 API key
  GOOGLE_API_KEY      - Google Imagen API key
  REPLICATE_API_KEY   - Replicate API key

Examples:
  IMAGE_PROVIDER=siliconflow SILICONFLOW_API_KEY=your_key npx ts-node clawgirlfriend-selfie.ts "a selfie at a cafe" "#general"
  IMAGE_PROVIDER=tongyi DASHSCOPE_API_KEY=your_key npx ts-node clawgirlfriend-selfie.ts "wearing a dress" "#fashion"
  npx ts-node clawgirlfriend-selfie.ts "vintage aesthetic" "#general,@user123" "✨" vintage
  npx ts-node clawgirlfriend-selfie.ts "night out at a club" "#general,#nightlife"
`);
    process.exit(1);
  }

  const [prompt, channel, caption, mode] = args;

  try {
    const result = await generateAndSend({
      prompt,
      channel,
      caption,
      mode: (mode as SelfieMode) || "auto",
    });
    console.log("\n--- Result ---");
    console.log(JSON.stringify(result, null, 2));
  } catch (error) {
    console.error(`[ERROR] ${(error as Error).message}`);
    process.exit(1);
  }
}

// Exports
export {
  generateImage,
  sendViaOpenClaw,
  generateAndSend,
  getProvider,
  PROVIDER_INFO,
  GenerateAndSendOptions,
  Result,
  ImageProvider,
  SelfieMode,
};

if (require.main === module) {
  main();
}

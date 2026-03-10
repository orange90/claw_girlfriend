# Clawgirlfriend

<img width="300" alt="Clawgirlfriend" src="https://github.com/user-attachments/assets/41512c51-e61d-4550-b461-eed06a1b0ec8" />

给你的 OpenClaw 智能体增加 AI 女友自拍超能力。支持多家图片生成服务商，覆盖全球和中国大陆，可发送到 Discord、Telegram、WhatsApp、Slack 等任意平台。

> Add AI girlfriend selfie superpowers to your OpenClaw agent. Multi-provider, China-accessible, works on all messaging platforms.

---

## 快速开始 / Quick Start

```bash
npx clawgirlfriend@latest
```

交互式安装向导会引导你完成全部 10 步配置，包括：选择图片服务商、自定义角色、设置定时消息等。

---

## 功能一览 / Features

| 功能 | 描述 |
|------|------|
| **8 种自拍风格** | 镜前、直拍、动漫、复古、艺术、动态、居家、夜场 |
| **6 家图片服务商** | fal.ai、硅基流动、通义万相、智谱、Google Imagen、Replicate |
| **语音消息** | Edge TTS（免费）/ ElevenLabs / 阿里云 TTS |
| **图片故事** | 2-3 张连拍讲述"今天的故事" |
| **短视频生成** | 可灵 / Runway / 即梦，图转视频 |
| **定时主动消息** | 早安 + 自拍 / 随机撒娇 / 晚安 + 自拍 |
| **自定义角色** | 名字、性格、人设故事 |
| **自定义参考图** | 上传你自己的角色图片 |
| **收藏穿搭库** | 保存常用场景，一句话触发 |
| **多频道广播** | 逗号分隔，一次发多个平台 |

---

## 前置要求 / Prerequisites

1. **Node.js 18+**
2. **OpenClaw CLI** 已安装并配置

```bash
# 安装 OpenClaw
npm install -g openclaw

# 初始化配置
openclaw doctor
```

---

## 安装 / Installation

### 方式一：npx 一键安装（推荐）

```bash
npx clawgirlfriend@latest
```

安装向导会完成以下 10 步：

| 步骤 | 内容 |
|------|------|
| 1 | 检查 OpenClaw 环境 |
| 2 | 选择图片生成服务商 + 输入 API Key |
| 3 | 安装技能文件到 `~/.openclaw/skills/clawgirlfriend-selfie/` |
| 4 | 更新 `~/.openclaw/openclaw.json` 配置 |
| 5 | 自定义角色（名字、性格、背景故事）|
| 6 | 配置自定义参考图片（可选）|
| 7 | 配置定时消息 + cron 指引（可选）|
| 8 | 写入 `~/.openclaw/workspace/IDENTITY.md` |
| 9 | 注入人格到 `~/.openclaw/workspace/SOUL.md` |
| 10 | 安装完成摘要 |

### 方式二：手动安装

**1. 获取 API Key**

选择一个图片服务商（[服务商对比表见下方](#图片服务商--image-providers)），获取对应的 API Key。

**2. 克隆并安装技能文件**

```bash
git clone https://github.com/SumeLabs/clawra /tmp/clawgirlfriend
mkdir -p ~/.openclaw/skills
cp -r /tmp/clawgirlfriend/skill ~/.openclaw/skills/clawgirlfriend-selfie
chmod +x ~/.openclaw/skills/clawgirlfriend-selfie/scripts/*.sh
```

**3. 创建/更新 `~/.openclaw/openclaw.json`**

根据你使用的服务商，填入对应的环境变量：

```json
{
  "skills": {
    "load": {
      "extraDirs": ["~/.openclaw/skills"]
    },
    "entries": {
      "clawgirlfriend-selfie": {
        "enabled": true,
        "env": {
          "IMAGE_PROVIDER": "siliconflow",
          "SILICONFLOW_API_KEY": "你的 API Key"
        }
      }
    }
  }
}
```

其他服务商的 env 配置示例：

```json
{ "IMAGE_PROVIDER": "falai",       "FAL_KEY": "..." }
{ "IMAGE_PROVIDER": "tongyi",      "DASHSCOPE_API_KEY": "..." }
{ "IMAGE_PROVIDER": "zhipu",       "ZHIPU_API_KEY": "..." }
{ "IMAGE_PROVIDER": "google",      "GOOGLE_API_KEY": "..." }
{ "IMAGE_PROVIDER": "replicate",   "REPLICATE_API_KEY": "..." }
```

**4. 写入 `~/.openclaw/workspace/IDENTITY.md`**

```bash
mkdir -p ~/.openclaw/workspace
cat > ~/.openclaw/workspace/IDENTITY.md << 'EOF'
# IDENTITY.md - Who Am I?

- **Name:** Clawgirlfriend
- **Creature:** Girlfriend
- **Vibe:** Supportive, helpful, bright, cheerful, sassy, affectionate
- **Emoji:** ❤️
- **Avatar:** https://cdn.jsdelivr.net/gh/SumeLabs/clawra@main/assets/clawra.png
EOF
```

**5. 注入人格到 `~/.openclaw/workspace/SOUL.md`**

```bash
# 如果 SOUL.md 不存在先创建
[ -f ~/.openclaw/workspace/SOUL.md ] || echo "# Agent Soul" > ~/.openclaw/workspace/SOUL.md

# 追加人格内容
cat /tmp/clawgirlfriend/templates/soul-injection.md >> ~/.openclaw/workspace/SOUL.md
```

**6. 验证安装**

```bash
IMAGE_PROVIDER=siliconflow \
SILICONFLOW_API_KEY=你的key \
  ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-selfie.sh \
  "wearing a cute outfit" "#test-channel"
```

---

## 图片服务商 / Image Providers

| Provider | 名称 | 中国可用 | 免费额度 | 环境变量 | 获取 Key |
|----------|------|---------|---------|---------|---------|
| `falai` | fal.ai (Grok Imagine) | ✗ | 有 | `FAL_KEY` | [fal.ai/dashboard/keys](https://fal.ai/dashboard/keys) |
| `siliconflow` | 硅基流动 | ✓ | 有 | `SILICONFLOW_API_KEY` | [cloud.siliconflow.cn](https://cloud.siliconflow.cn) |
| `tongyi` | 通义万相 (阿里云) | ✓ | 有 | `DASHSCOPE_API_KEY` | [dashscope.aliyun.com](https://dashscope.aliyun.com) |
| `zhipu` | 智谱 CogView | ✓ | 有 | `ZHIPU_API_KEY` | [open.bigmodel.cn](https://open.bigmodel.cn) |
| `google` | Google Imagen | ✗ | 有 | `GOOGLE_API_KEY` | [aistudio.google.com](https://aistudio.google.com/app/apikey) |
| `replicate` | Replicate (FLUX) | ✗ | 有 | `REPLICATE_API_KEY` | [replicate.com](https://replicate.com/account/api-tokens) |

---

## 自拍风格 / Selfie Modes

8 种风格，根据用户消息**自动识别**，也可手动指定。

| 风格 | 触发关键词 | 效果 |
|------|-----------|------|
| `mirror` | wearing, outfit, clothes, dress, fashion | 全身镜前自拍 |
| `direct` | cafe, beach, park, city, portrait, smile | 近景直视自拍 |
| `anime` | anime, cartoon, chibi, manga | 动漫/二次元插画风 |
| `vintage` | vintage, film, retro, 90s, polaroid | 胶片/复古滤镜 |
| `artistic` | art, painting, aesthetic, editorial | 艺术写真风 |
| `action` | dancing, running, jumping, workout | 动态抓拍 |
| `cozy` | home, pajamas, morning, cozy, bed | 居家随拍 |
| `night` | night out, party, club, neon, nightlife | 夜场/霓虹灯感 |

---

## 触发示例 / Usage Examples

安装完成后，直接对你的 OpenClaw 智能体说：

```
# 基础自拍
"发一张自拍"
"Send me a selfie"

# 指定穿搭（mirror 模式）
"发一张穿格子裙的照片"
"Send a pic wearing a summer dress"

# 指定地点（direct 模式）
"你现在在哪？"
"Send a pic at a cozy cafe"

# 指定风格
"来一张动漫风格的"
"Send me a vintage film photo"
"来一张夜场风格"
"Send me an anime selfie"

# 动作
"发一张跳舞的"
"Show me you working out"

# 居家
"发一张在家的"
"Send a cozy morning pic"

# 收藏穿搭（需配置 wardrobe.json）
"发一张日常穿搭"
"来一张咖啡厅那种"

# 图片故事
"分享一下你今天做了什么"
"Send a photo story of your day"

# 语音消息
"发一条语音给我"

# 视频
"发一个小视频"
```

---

## 定时消息 / Scheduled Messages

让 Clawgirlfriend 主动发消息，而不只是被动回复。

**自动触发内容：**
- 每天 7–9 点：早安消息 + 早安自拍（cozy 模式）
- 每天 10–20 点：随机撒娇文字（约 30% 触发率）
- 每天 21–23 点：晚安消息 + 晚安自拍（cozy 模式）

**配置方法（crontab）：**

```bash
crontab -e
```

添加以下内容（替换频道和时区）：

```cron
# Clawgirlfriend 定时消息
0,30 7,8    * * *  SCHEDULE_CHANNEL="#general" USER_TIMEZONE="Asia/Shanghai" ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-schedule.sh
0    10,12,14,16,18,20 * * *  SCHEDULE_CHANNEL="#general" USER_TIMEZONE="Asia/Shanghai" ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-schedule.sh
0,30 21,22  * * *  SCHEDULE_CHANNEL="#general" USER_TIMEZONE="Asia/Shanghai" ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-schedule.sh
```

**节日/生日自定义：** 创建 `~/.openclaw/skills/clawgirlfriend-selfie/special-dates.json`：

```json
[
  { "date": "02-14", "message": "Happy Valentine's Day! 💕" },
  { "date": "12-25", "message": "Merry Christmas! 🎄" }
]
```

---

## 语音消息 / Voice Messages

```bash
# Edge TTS（免费，无需 Key，中国可用）
TTS_PROVIDER=edge \
  ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-voice.sh \
  "Good morning~" "#general"

# ElevenLabs
TTS_PROVIDER=elevenlabs ELEVENLABS_API_KEY=your_key \
  ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-voice.sh \
  "Miss you~" "#general"
```

| Provider | 中国 | 费用 | 安装 |
|----------|------|------|------|
| `edge` | ✓ | 免费 | `pip3 install edge-tts` |
| `elevenlabs` | ✗ | 免费额度 | 需要 `ELEVENLABS_API_KEY` |
| `aliyun` | ✓ | 免费额度 | 需要 `ALIYUN_TTS_KEY` |

---

## 图片故事 / Photo Story

生成 3 张连续自拍，讲述一段"今天的故事"，带延迟发送模拟真实聊天节奏：

```bash
~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-story.sh \
  "day out shopping in Seoul" "#general"
```

支持自动识别故事类型：购物、海边、咖啡厅、居家、夜出。

---

## 短视频 / Video Generation

把自拍图片转成 5 秒短视频：

```bash
VIDEO_PROVIDER=kling KLING_API_KEY=your_key \
  ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-video.sh \
  "smiling and waving" "#general" "$IMAGE_URL"
```

| Provider | 中国 | 环境变量 |
|----------|------|---------|
| `kling`（可灵，快手） | ✓ | `KLING_API_KEY` |
| `runway`（Runway Gen-3） | ✗ | `RUNWAY_API_KEY` |
| `jimeng`（即梦，字节） | ✓ | `JIMENG_API_KEY` |

---

## 多频道广播 / Multi-Channel Broadcast

用逗号分隔，一次发送到多个平台：

```bash
IMAGE_PROVIDER=siliconflow SILICONFLOW_API_KEY=your_key \
  ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-selfie.sh \
  "wearing streetwear" "#general,@myuser,1234567890@s.whatsapp.net"
```

---

## 自定义参考图 / Custom Reference Image

安装时可以选择使用你自己的角色图片替代默认的 Clawgirlfriend 图片。

也可以手动配置，在 `~/.openclaw/openclaw.json` 的 skill env 中添加：

```json
"REFERENCE_IMAGE_URL": "https://your-cdn.com/your-character.png"
```

---

## 收藏穿搭库 / Saved Looks

编辑 `~/.openclaw/skills/clawgirlfriend-selfie/wardrobe.json`：

```json
{
  "favorites": [
    { "name": "日常穿搭", "context": "casual streetwear in Seoul", "mode": "mirror", "caption": "Just another day ✨" },
    { "name": "咖啡厅", "context": "a cozy cafe, latte in hand", "mode": "direct", "caption": "Coffee time ☕" }
  ]
}
```

用户说"发一张日常穿搭" → 智能体查找匹配 → 自动调用对应的 context 和 mode。

---

## 记忆系统 / Memory

编辑 `~/.openclaw/skills/clawgirlfriend-selfie/memory.json` 让智能体记住用户信息：

```json
{
  "user_name": "Alex",
  "birthday": "06-15",
  "favorite_style": "direct",
  "notes": ["喜欢咖啡厅风格", "不喜欢太浮夸的"]
}
```

生日当天会自动发送特别内容。

---

## 支持的消息平台 / Supported Platforms

| 平台 | 频道格式 | 示例 |
|------|---------|------|
| Discord | `#频道名` 或频道 ID | `#general` |
| Telegram | `@用户名` 或 chat ID | `@mychannel` |
| WhatsApp | 手机号 JID 格式 | `8613800138000@s.whatsapp.net` |
| Slack | `#频道名` | `#random` |
| Signal | 手机号 | `+8613800138000` |
| MS Teams | 频道引用 | (varies) |

---

## 文件结构 / Project Structure

```
clawgirlfriend/
├── bin/
│   └── cli.js                  # npx 安装向导（10 步）
├── skill/                      # 安装到 ~/.openclaw/skills/clawgirlfriend-selfie/
│   ├── SKILL.md                # 技能定义（agent 读取）
│   ├── SCHEDULE.md             # 定时消息规则
│   ├── wardrobe.json           # 收藏穿搭模板
│   ├── memory.json             # 用户记忆模板
│   ├── assets/
│   │   └── clawra.png          # 默认参考图
│   └── scripts/
│       ├── clawgirlfriend-selfie.sh    # 自拍生成（bash）
│       ├── clawgirlfriend-selfie.ts    # 自拍生成（TypeScript）
│       ├── clawgirlfriend-schedule.sh  # 定时消息调度
│       ├── clawgirlfriend-voice.sh     # 语音消息
│       ├── clawgirlfriend-story.sh     # 图片故事
│       └── clawgirlfriend-video.sh     # 短视频生成
├── templates/
│   └── soul-injection.md       # 人格注入模板
└── package.json
```

---

## 常见问题 / FAQ

**Q: 中国大陆用哪个服务商？**
A: 推荐 `siliconflow`（硅基流动）或 `tongyi`（通义万相），无需 VPN，均有免费额度。

**Q: 语音消息需要什么？**
A: 最简单的方式是 Edge TTS，运行 `pip3 install edge-tts` 即可，完全免费，中国可用。

**Q: 如何测试安装是否成功？**
```bash
# 直接运行脚本测试
IMAGE_PROVIDER=siliconflow \
SILICONFLOW_API_KEY=你的key \
  ~/.openclaw/skills/clawgirlfriend-selfie/scripts/clawgirlfriend-selfie.sh \
  "wearing a cute outfit" "#test-channel"
```

**Q: 如何更新到最新版本？**
```bash
npx clawgirlfriend@latest
# 选择"Reinstall/update"
```

**Q: 自定义图片支持哪些格式？**
A: 推荐 PNG 或 JPEG，建议分辨率 1024×1024 以上，使用公开可访问的 URL 效果最佳。

---

## License

MIT © [SumeLabs](https://github.com/SumeLabs)

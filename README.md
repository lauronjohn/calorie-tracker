# calorie-tracker

John's calorie tracker — a minimal iOS app for logging meals, with AI photo analysis.

Photograph a meal (or type what you ate) and it comes back broken into items with
estimated calories and macros. You review and edit the estimate, then it's logged
against your daily goal.

- **iOS 17+**, SwiftUI, SwiftData
- **Two AI providers, switchable in Settings** — Claude, or any OpenAI-compatible
  endpoint (Qwen, OpenRouter, OpenAI, a local server)
- **Your API key stays on your device**, in the iOS Keychain. No backend.

## Setup

The Xcode project is generated rather than checked in, so the repo stays diffable.

```bash
brew install xcodegen
xcodegen generate
open CalorieTracker.xcodeproj
```

Then ⌘R to run, ⌘U for tests.

## First run

1. Open **Settings** in the app.
2. Pick a provider and paste an API key, then **Save key**.
3. Tap **Test connection** — a green check means the key, model and network path all
   work. A red cross shows the provider's actual error message.
4. Set your daily goals.

The simulator has no camera, so use **Choose photo** there. The camera path needs a
real device.

## Providers

| Provider | Base URL | Example model |
| --- | --- | --- |
| Claude | *(built in)* | `claude-opus-5` |
| Qwen (Alibaba Model Studio) | `https://dashscope-intl.aliyuncs.com/compatible-mode/v1` | `qwen3-vl-plus` |
| OpenRouter | `https://openrouter.ai/api/v1` | `qwen/qwen3-vl-235b-a22b-instruct` |
| OpenAI | `https://api.openai.com/v1` | `gpt-4o` |

Anything speaking the OpenAI chat-completions format works — set the base URL and
model and go. **The model must accept images**; a text-only model fails on the photo
flow and works fine for typed entries.

**DeepSeek can't do the photo feature.** As of July 2026 its public API is text-only —
there's no image content type on the V4 models. Vision exists in DeepSeek's chat UI
and as open weights, but not on the API.

Rough cost per photo, at roughly 2k input / 400 output tokens: about 2¢ on
`claude-opus-5`, about 1¢ on `claude-sonnet-5`, less on Haiku or Qwen. Photos are
downscaled to a 1568 px long edge before upload, which keeps image tokens down;
raise `ImageProcessing.maxLongEdge` if you start shooting labels with small print.

## How the estimates work

Both providers get the same prompt and the same JSON schema, so results stay
comparable when you switch.

The model is asked for **per-item numbers only — never totals**. Totals are summed on
the phone. Every item carries a confidence level, and the response carries the
assumptions that materially affect the numbers ("cooked without added oil", "portion
estimated from plate size"). All of it is shown on the review screen before anything
is logged, and every field is editable.

This is deliberate. Calorie estimates from a photo are estimates; the app is built to
show them as such rather than present a number as fact.

## Layout

```
project.yml                     XcodeGen project definition
Sources/CalorieTracker/
  App/                          entry point, tab shell
  Models/                       FoodEntry, FoodItem (SwiftData)
  Persistence/DayTotals         totals and day grouping — pure, unit-tested
  AI/                           FoodAnalyzing protocol + the two clients + shared schema
  Security/KeychainStore        API key storage
  Settings/AppSettings          provider, model, goals
  Features/                     Today, Analysis, Capture, ManualEntry, History, Settings
  Utilities/ImageProcessing     downscale + JPEG encode
Tests/CalorieTrackerTests/      totals, JSON decoding, image processing
```

Feature code depends only on the `FoodAnalyzing` protocol — `AnalyzerFactory` is the
one place that knows which concrete provider exists. Adding a third provider means
one new file and one case.

## Not included

Barcode scanning. It needs a nutrition database (Open Food Facts or similar) and is
a meaningfully larger piece of work than the rest of v1.

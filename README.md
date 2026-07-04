# MailAssistant

An iOS email assistant that reads, searches, sends, and replies to Gmail, and can schedule Google Meet meetings on your calendar — all through a chat interface backed by an LLM agent built on **swift-koog**.

This project exists primarily as a **demo app for [swift-koog](https://github.com/nwudoebuka/swift-koog)**, a Swift package that bridges [JetBrains' Koog agent framework](https://github.com/JetBrains/koog) (Kotlin Multiplatform) into native Swift/iOS via Kotlin/Native interop. MailAssistant is the reference consumer showing what building a real tool-using LLM agent on top of `SwiftKoog` looks like end to end: tool definitions, human-in-the-loop approval, and a multi-turn chat UI.

## How it works

- **`Sources/MailAssistant/Auth`** — Google Sign-In (`GoogleSignIn-iOS`), requesting `gmail.modify` and `calendar.events` scopes.
- **`Sources/MailAssistant/Tools`** — `GmailService`/`CalendarService` wrap the Gmail and Calendar REST APIs; `GmailTools.swift` and `MeetTool.swift` expose them as `KoogTool`s the agent can call (list/search/read/send/reply/draft/mark-read/archive emails, schedule a Meet).
- **`Sources/MailAssistant/Agent/MailAgent.swift`** — builds a `KoogAgent` (from `SwiftKoog`) configured with an LLM provider, the system prompt, and the tool list. This app defaults to Anthropic's Claude, but `SwiftKoog`'s `LLMProvider` is not Claude-specific — see below for swapping in a different provider/model. Sensitive actions (sending mail, scheduling meetings) go through an approval handler before executing.
- **`Sources/MailAssistant/Chat`** — the SwiftUI chat surface (`ChatView`/`ChatViewModel`) that drives the agent and renders its responses/tool calls.

### About swift-koog

`SwiftKoog` (declared as a dependency in `project.yml`) is a thin Swift API over a compiled Kotlin Multiplatform `KoogBridge.xcframework`. It exposes:

- `KoogAgent` — a `Sendable` Swift class wrapping Koog's `AIAgent`, supporting single-turn and multi-turn (history-based) runs.
- `LLMProvider` — **not tied to any single vendor.** Options are `.anthropic`, `.openai`, `.ollama` (local/self-hosted models), or `.chain([...])` to try multiple providers in order with automatic failover.
- `KoogTool` / `ApprovableTool` — protocols for defining tools the agent can invoke, with optional human-in-the-loop approval before execution.

Under the hood, `KoogAgentBridge.kt` (Kotlin) talks to Koog's `AnthropicLLMClient`/`OpenAILLMClient`, using Koog's own predefined model constants (e.g. `AnthropicModels.Sonnet_4_5`) so requests match what Koog's SDK actually supports.

#### Swapping the LLM provider/model

`MailAgent.swift` picks the provider in one place:

```swift
llm: .anthropic(apiKey: llmAPIKey, model: "claude-sonnet-4-5"),
```

Any `LLMProvider` case works here, for example:

```swift
// Anthropic — other Claude models
.anthropic(apiKey: key, model: "claude-opus-4-5")
.anthropic(apiKey: key, model: "claude-haiku-4-5")

// OpenAI
.openai(apiKey: key, model: "gpt-4o")
.openai(apiKey: key, model: "gpt-4.1-mini")

// Ollama — local/self-hosted, no API key needed
.ollama(model: "llama3")

// Automatic failover across providers
.chain([
    .anthropic(apiKey: anthropicKey, model: "claude-sonnet-4-5"),
    .openai(apiKey: openAIKey, model: "gpt-4o"),
    .ollama(model: "llama3"),
])
```

Switching providers is just a matter of changing this one call — the tool definitions, approval flow, and chat UI are all provider-agnostic.

## Prerequisites

- Xcode 15+, iOS 16+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- A Google Cloud project with the **Gmail API** and **Google Calendar API** enabled
- An API key for whichever LLM provider you configure in `MailAgent.swift` — this project defaults to an [Anthropic API key](https://console.anthropic.com), but see [Swapping the LLM provider/model](#swapping-the-llm-providermodel) if you'd rather use OpenAI or a local Ollama model

## Setup

### 1. Google Sign-In / API access

1. In [Google Cloud Console](https://console.cloud.google.com), enable the **Gmail API** and **Google Calendar API** for your project.
2. Under **APIs & Services → OAuth consent screen**, add the `gmail.modify` and `calendar.events` scopes, and add your Google account as a test user (while the app is unverified/in Testing mode).
3. Under **APIs & Services → Credentials**, create an **OAuth client ID** of type **iOS**, using bundle ID `com.swiftkoog.MailAssistant` (or whatever you set `PRODUCT_BUNDLE_IDENTIFIER` to in `project.yml`).
4. From the downloaded client plist, copy:
   - `CLIENT_ID` → `Sources/MailAssistant/Resources/Info.plist` → `GIDClientID`
   - `REVERSED_CLIENT_ID` → `Info.plist` → `CFBundleURLTypes[0].CFBundleURLSchemes[0]`

### 2. LLM API key

Secrets are kept out of source via an untracked `.xcconfig` file. By default this project uses Anthropic:

1. Copy the template: `cp Secrets.xcconfig.example Secrets.xcconfig`
2. Edit `Secrets.xcconfig` and set `LLM_API_KEY` to your real key — from the [Anthropic Console](https://console.anthropic.com) by default, or your chosen provider's key if you've switched (see below).

`Secrets.xcconfig` is gitignored and wired into the build via `project.yml`'s `configFiles`, exposed through `Info.plist` as `$(LLM_API_KEY)`, and read at runtime in `MailAgent.swift` via `Bundle.main`. The key name is generic (`LLM_API_KEY`, not `ANTHROPIC_API_KEY`) since `SwiftKoog` isn't tied to one provider — swap providers in `MailAgent.swift` and this same variable carries whichever key you're using. If the key is missing, the app will `fatalError` on launch with a message pointing back here — this is a demo app, not a shipped product, so failing loudly beats failing silently.

Ollama needs no key at all since it runs locally.

### 3. Generate and build the Xcode project

```
xcodegen generate
open MailAssistant.xcodeproj
```

Select a development team for code signing (`CODE_SIGN_STYLE: Automatic`), then build and run.

## Project structure

```
project.yml                     # XcodeGen project definition
Secrets.xcconfig.example        # template — copy to Secrets.xcconfig (gitignored)
Sources/MailAssistant/
  MailAssistantApp.swift        # app entry point
  Auth/                         # Google Sign-In
  Agent/MailAgent.swift         # KoogAgent construction (SwiftKoog)
  Tools/                        # Gmail/Calendar services + KoogTool implementations
  Chat/                         # chat UI
  Resources/Info.plist
```

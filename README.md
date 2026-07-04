# MailAssistant

An iOS email assistant that reads, searches, sends, and replies to Gmail, and can schedule Google Meet meetings on your calendar — all through a chat interface backed by Claude.

This project exists primarily as a **demo app for [swift-koog](https://github.com/nwudoebuka/swift-koog)**, a Swift package that bridges [JetBrains' Koog agent framework](https://github.com/JetBrains/koog) (Kotlin Multiplatform) into native Swift/iOS via Kotlin/Native interop. MailAssistant is the reference consumer showing what building a real tool-using LLM agent on top of `SwiftKoog` looks like end to end: tool definitions, human-in-the-loop approval, and a multi-turn chat UI.

## How it works

- **`Sources/MailAssistant/Auth`** — Google Sign-In (`GoogleSignIn-iOS`), requesting `gmail.modify` and `calendar.events` scopes.
- **`Sources/MailAssistant/Tools`** — `GmailService`/`CalendarService` wrap the Gmail and Calendar REST APIs; `GmailTools.swift` and `MeetTool.swift` expose them as `KoogTool`s the agent can call (list/search/read/send/reply/draft/mark-read/archive emails, schedule a Meet).
- **`Sources/MailAssistant/Agent/MailAgent.swift`** — builds a `KoogAgent` (from `SwiftKoog`) configured with Anthropic's Claude as the LLM, the system prompt, and the tool list. Sensitive actions (sending mail, scheduling meetings) go through an approval handler before executing.
- **`Sources/MailAssistant/Chat`** — the SwiftUI chat surface (`ChatView`/`ChatViewModel`) that drives the agent and renders its responses/tool calls.

### About swift-koog

`SwiftKoog` (declared as a dependency in `project.yml`) is a thin Swift API over a compiled Kotlin Multiplatform `KoogBridge.xcframework`. It exposes:

- `KoogAgent` — a `Sendable` Swift class wrapping Koog's `AIAgent`, supporting single-turn and multi-turn (history-based) runs.
- `LLMProvider` — `.anthropic`, `.openai`, `.ollama`, or `.chain([...])` for automatic provider failover.
- `KoogTool` / `ApprovableTool` — protocols for defining tools the agent can invoke, with optional human-in-the-loop approval before execution.

Under the hood, `KoogAgentBridge.kt` (Kotlin) talks to Koog's `AnthropicLLMClient`/`OpenAILLMClient`, using Koog's own predefined model constants (e.g. `AnthropicModels.Sonnet_4_5`) so requests match what Koog's SDK actually supports.

## Prerequisites

- Xcode 15+, iOS 16+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- A Google Cloud project with the **Gmail API** and **Google Calendar API** enabled
- An [Anthropic API key](https://console.anthropic.com)

## Setup

### 1. Google Sign-In / API access

1. In [Google Cloud Console](https://console.cloud.google.com), enable the **Gmail API** and **Google Calendar API** for your project.
2. Under **APIs & Services → OAuth consent screen**, add the `gmail.modify` and `calendar.events` scopes, and add your Google account as a test user (while the app is unverified/in Testing mode).
3. Under **APIs & Services → Credentials**, create an **OAuth client ID** of type **iOS**, using bundle ID `com.swiftkoog.MailAssistant` (or whatever you set `PRODUCT_BUNDLE_IDENTIFIER` to in `project.yml`).
4. From the downloaded client plist, copy:
   - `CLIENT_ID` → `Sources/MailAssistant/Resources/Info.plist` → `GIDClientID`
   - `REVERSED_CLIENT_ID` → `Info.plist` → `CFBundleURLTypes[0].CFBundleURLSchemes[0]`

### 2. Anthropic API key

Secrets are kept out of source via an untracked `.xcconfig` file:

1. Copy the template: `cp Secrets.xcconfig.example Secrets.xcconfig`
2. Edit `Secrets.xcconfig` and set `ANTHROPIC_API_KEY` to your real key from the [Anthropic Console](https://console.anthropic.com).

`Secrets.xcconfig` is gitignored and wired into the build via `project.yml`'s `configFiles`, exposed through `Info.plist` as `$(ANTHROPIC_API_KEY)`, and read at runtime in `MailAgent.swift` via `Bundle.main`. If the key is missing, the app will `fatalError` on launch with a message pointing back here — this is a demo app, not a shipped product, so failing loudly beats failing silently.

Note: this app talks to Anthropic directly from the client for demo simplicity. For anything beyond local/personal use, route LLM calls through a backend you control instead of shipping the API key in the app.

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

# TextKit PRD + Build Sheet

## Product

**TextKit**

**One-liner:** Transform any copied text instantly with a fast, private AI running entirely on your device.

## Product Summary

TextKit is a macOS menu bar utility that watches the clipboard, classifies copied text, precomputes the most likely transformation using a lightweight local model, and presents the result in a native-feeling popover. The app is designed to feel instant, private, and always available without turning into a full chat application.

## Core Product Thesis

Users copy text constantly. Most copied text falls into one of four intents:

1. rewrite this
2. turn this into a better prompt
3. pull the important information out
4. help me respond to this

TextKit should intercept that moment and make the next step immediate.

## Goals

- Feel instant or near-instant for common clipboard actions
- Run fully on-device for privacy
- Keep UI lightweight and native to macOS
- Support model and quant preset selection without exposing too much low-level complexity by default
- Use a single small local model plus constrained prompt templates

## Non-Goals

- General chat UI
- Long-form reasoning assistant
- Document QA over large files
- Cloud inference dependency for core product flow
- Agentic multi-step workflows

## User Experience Principles

- Clipboard-first
- One glance to understand the result
- One click to copy
- Fast defaults, optional refinement
- Advanced settings available but hidden from the main interaction surface

## Main User Flow

1. User copies text anywhere on macOS
2. Clipboard watcher detects change
3. TextKit runs a lightweight routing pass
4. TextKit selects the most likely tool
5. TextKit precomputes one likely output and caches it
6. User opens TextKit from the menu bar or hotkey
7. The matching tool is already selected with an output ready
8. User optionally changes tool, mode, or refine instruction
9. User copies result back to clipboard

## The 4 Tools

### 1. Rewrite

Purpose: Improve or restyle existing text

Sub-modes:

- Clean
- Short
- Professional
- Bullet

Typical inputs:

- rough Slack message
- informal email
- messy notes
- rambling paragraph

Typical outputs:

- cleaner rewrite
- condensed version
- more polished tone
- bullet format

### 2. Prompt

Purpose: Turn rough intent into a stronger AI-ready prompt

Sub-modes:

- Balanced
- Detailed
- Constrained
- Creative

Typical inputs:

- rough request
- vague AI task idea
- short instruction

Typical outputs:

- structured prompt
- explicit constraints
- clearer task framing
- improved output guidance

### 3. Extract

Purpose: Pull structured information from messy text

Sub-modes:

- Action Items
- Key Points
- Entities
- Dates

Typical inputs:

- meeting notes
- email body
- copied paragraph
- request list

Typical outputs:

- bullets
- extracted names/roles
- deadlines and dates
- concise summary facts

### 4. Reply

Purpose: Draft a response to copied text

Sub-modes:

- Casual
- Professional
- Concise
- Warm

Typical inputs:

- inbound email snippet
- Slack message
- recruiter outreach
- follow-up text

Typical outputs:

- reply draft matching tone preset

## Why These 4 Work Together

All four tools operate on short copied text. They are different enough to feel purposeful, but close enough to share the same interaction model, local model, and caching strategy.

## Clipboard Routing Strategy

Use smart precompute, not full precompute for every tool.

### Routing Decision Rules

Start with rules first, then optionally upgrade to model-assisted routing.

#### Rule-based heuristics v1

**Reply likely if:**

- message contains second-person conversational phrasing
- message starts with greeting or follow-up language
- message sounds like inbound communication
- examples: "just checking in", "let me know", "thanks for reaching out"

**Extract likely if:**

- text contains dates, times, named entities, or multiple requests
- examples: "tomorrow", "Friday", "2pm", "send this before then"

**Prompt likely if:**

- text resembles a request to an AI system
- examples: "write a prompt", "help me generate", "create a plan for"

**Rewrite default if:**

- none of the above are strong enough

### Routing Behavior

- Run routing on clipboard change
- Precompute exactly one likely tool by default
- Optionally precompute Rewrite as a fallback if the input is short and compute budget allows
- Cache result in memory for immediate display

## Local Model Strategy

### Recommended Default Model

**Qwen2.5 0.5B Instruct**

Reasoning:

- very small footprint
- strong instruction following for its size
- suitable for short transformations, extraction, prompt improvement, and short replies
- appropriate for near-instant menu bar utility behavior

### Optional Model Tier

Add an advanced option later for a 1B-class model if users want higher quality.

## Model Profiles

Expose simple profiles first:

- **Fast**
  - smallest footprint
  - best for background precompute
- **Balanced**
  - slightly higher quality
  - still practical locally
- **Quality**
  - optional future tier
  - not default for background precompute

## Quantization Strategy

Do not expose raw quant jargon first in the main UX.

### User-facing preset labels

- Fast
- Balanced
- Quality

### Advanced mapping example

- Fast → Q4\_K\_S
- Balanced → Q4\_K\_M
- Quality → Q5\_K\_M

## Inference Lifecycle

### Recommended Lifecycle

**Lazy load with warm cache**

Behavior:

- app boots without model fully loaded
- clipboard watcher runs cheaply
- when a clipboard event requires precompute, spin up model if needed
- keep model warm for a short idle window after last use
- unload after inactivity if memory pressure is detected or timeout expires

### Suggested timings

- clipboard watcher polling: 300–800 ms using pasteboard change count
- warm retention after inference: 30–90 seconds
- unload on memory pressure or prolonged inactivity

## Performance Targets

### User-perceived targets

- route decision: under 50 ms if rule-based
- precompute start after clipboard change: under 150 ms
- visible result on popover open when cached: instant
- on-demand generation after changing mode: ideally under 500 ms for short text

### Target behavior by tool

- Rewrite: fastest
- Extract: fast
- Reply: moderate
- Prompt: slowest of the four but still brief

## Prompt Template System

Use a strict system prompt plus concise mode-specific task prompt. Small models perform best when prompts are constrained and output format is explicit.

### Shared System Prompt

```text
You are TextKit, a local macOS text utility.
You transform copied text according to the selected tool and mode.
Do not explain your reasoning.
Do not add commentary.
Return only the final output.
Keep outputs concise, paste-ready, and aligned to the selected tool.
If the user adds a refine instruction, apply it only within the bounds of the selected tool and mode.
```

---

## Prompt Templates By Tool

### Rewrite

#### Rewrite / Clean

```text
Task: Rewrite the text for clarity.
Preserve the original meaning.
Remove awkward phrasing.
Return only the rewritten text.
```

#### Rewrite / Short

```text
Task: Rewrite the text in fewer words.
Preserve intent.
Remove filler.
Return only the shortened text.
```

#### Rewrite / Professional

```text
Task: Rewrite the text in a polished professional tone.
Preserve the meaning.
Avoid sounding robotic.
Return only the rewritten text.
```

#### Rewrite / Bullet

```text
Task: Convert the text into concise bullet points.
Keep only the important content.
Return bullet points only.
```

### Prompt

#### Prompt / Balanced

```text
Task: Turn the text into a strong AI prompt.
Clarify the goal.
Make the request explicit.
Add useful output guidance.
Return only the final prompt.
```

#### Prompt / Detailed

```text
Task: Turn the text into a detailed AI prompt.
Clarify the goal, desired output, important constraints, and relevant context.
Return only the final prompt.
```

#### Prompt / Constrained

```text
Task: Turn the text into an AI prompt with explicit constraints.
State the task clearly.
Include brevity and output format guidance.
Return only the final prompt.
```

#### Prompt / Creative

```text
Task: Turn the text into a sharper, more creative AI prompt.
Keep the request clear but allow more style and voice.
Return only the final prompt.
```

### Extract

#### Extract / Action Items

```text
Task: Extract action items from the text.
Return concise bullet points.
If no action items are present, return: No action items found.
```

#### Extract / Key Points

```text
Task: Extract the key points from the text.
Return concise bullet points.
Do not include commentary.
```

#### Extract / Entities

```text
Task: Extract important entities from the text.
Include people, organizations, roles, products, or places when present.
Return concise bullet points.
If none are found, return: No notable entities found.
```

#### Extract / Dates

```text
Task: Extract dates, times, and deadlines from the text.
Return concise bullet points.
If none are found, return: No dates or times found.
```

### Reply

#### Reply / Casual

```text
Task: Draft a casual reply to the text.
Keep it natural and concise.
Return only the reply.
```

#### Reply / Professional

```text
Task: Draft a professional reply to the text.
Keep it polite, clear, and concise.
Return only the reply.
```

#### Reply / Concise

```text
Task: Draft a very concise reply to the text.
Use as few words as possible while preserving usefulness.
Return only the reply.
```

#### Reply / Warm

```text
Task: Draft a warm and thoughtful reply to the text.
Keep it natural and not overly long.
Return only the reply.
```

## Refine Instruction Handling

The refine field should layer on top of the selected template, not replace it.

### Prompt assembly order

1. Shared system prompt
2. Tool + mode prompt
3. Optional refine instruction
4. Input text

### Example assembly

```text
System:
You are TextKit...

Mode Prompt:
Task: Rewrite the text in a polished professional tone...

Refine Instruction:
Make it more confident and slightly shorter.

Input:
<copied text>
```

## Settings Pane

### Main Settings

- Model profile
- Quantization preset
- Auto-clip enabled toggle
- Launch at login
- Hotkey customization
- Default tool fallback
- Warm cache duration

### Advanced Settings

- Exact model file
- Exact quant file
- Context limit
- Max output tokens
- Temperature per tool
- Debug logging
- Manual model download management

## Suggested Default Generation Parameters

Small models benefit from conservative defaults.

### Rewrite

- temperature: 0.2
- max tokens: 120

### Prompt

- temperature: 0.35
- max tokens: 180

### Extract

- temperature: 0.1
- max tokens: 120

### Reply

- temperature: 0.35
- max tokens: 140

## UI Requirements

### Surface

- Menu bar icon
- Popover panel
- Optional keyboard shortcut

### Header

- app name: TextKit
- tool tabs in header
- settings button
- subtle local/on-device status label

### Body

- input card
- refine field
- mode pills for current tool
- output card
- copy button

### Settings

- collapsible pane or dedicated settings sheet
- presets first, advanced section behind disclosure

## macOS Implementation Notes

- Use `MenuBarExtra`
- Use `NSPasteboard.general.changeCount` for clipboard monitoring
- Keep watcher cheap and separate from inference
- Keep inference work off the main thread
- Cache latest clipboard text and latest generated result per tool when appropriate

## Internal Architecture

### Modules

- ClipboardMonitor
- RouteEngine
- ModelManager
- PromptComposer
- InferenceEngine
- CacheStore
- SettingsStore
- PopoverViewModel

### Responsibilities

#### ClipboardMonitor

- polls pasteboard change count
- emits new clipboard text events

#### RouteEngine

- classifies clipboard text into one likely tool
- starts rule-based
- can later be replaced or augmented by model-assisted routing

#### ModelManager

- knows installed models and quant files
- loads/unloads model
- tracks warm state

#### PromptComposer

- builds final prompts from tool, mode, refine, and input

#### InferenceEngine

- runs local generation
- enforces token and timeout limits

#### CacheStore

- caches last input and output
- stores precomputed results keyed by clipboard hash + tool + mode + template + model

#### SettingsStore

- persists chosen model profile, quant preset, defaults, and toggles

## Cache Strategy

### Key

- clipboard hash
- selected tool
- selected sub-mode
- active template
- model profile / quant preset
- refine instruction if present

### Rules

- invalidate cache when clipboard changes
- invalidate cache when model or template changes
- preserve last output for quick re-open when input is unchanged

## Error Handling

- if model is unavailable, show a local status and offer to download
- if inference times out, fall back to simpler output or suggest switching to Fast profile
- if extraction finds nothing, return explicit no-result message instead of blank output

## Privacy Requirements

- all transforms local by default
- no clipboard upload to cloud in core flow
- clear user-facing messaging that processing is on-device

## Telemetry

Default to minimal or none. If analytics are ever added, never include copied text content.

## Build Phases

### Phase 1: Foundation

- MenuBarExtra app shell
- clipboard watcher
- popover UI
- settings persistence
- fake outputs for all four tools

### Phase 2: Local Model Integration

- integrate llama.cpp or equivalent runtime
- load Qwen2.5 0.5B GGUF
- build prompt composer
- implement one tool end-to-end first

### Phase 3: Smart Routing + Precompute

- add rule-based router
- precompute one likely tool
- cache result
- show cached result instantly on open

### Phase 4: Polish

- warm loading lifecycle
- download manager for model files
- advanced settings
- latency tuning
- memory pressure handling

## Suggested Build Order for Codex

1. Scaffold SwiftUI MenuBarExtra app
2. Add clipboard monitoring service
3. Add TextKit popover UI shell
4. Add tool tabs and mode pills
5. Add settings pane and persistence
6. Stub fake generation outputs
7. Add prompt composer module
8. Integrate local model runtime
9. Wire one tool: Rewrite / Clean
10. Wire remaining tools and modes
11. Add router and precompute cache
12. Optimize load/unload lifecycle
13. Add model/quant download management
14. Add final polish and QA

## Acceptance Criteria

- App launches as a menu bar utility
- Copied text appears in the input panel
- User can switch between Rewrite, Prompt, Extract, and Reply
- Each tool supports its sub-modes
- Refine instruction changes output behavior
- Settings allow choosing model profile and quant preset
- Rule-based router selects one likely tool after copy
- One likely result is precomputed and shown instantly on open
- Outputs remain local and paste-ready
- Copy button writes final result back to clipboard

## Open Decisions

- exact runtime: llama.cpp vs MLX-backed path
- whether to support multiple model families at v1 or just one
- whether precompute should happen immediately on clipboard change or only when app is warm
- whether to keep the model always warm for a short window or fully unload after every use

## Recommended v1 Decisions

- use one model family only
- use rule-based routing first
- precompute one likely tool only
- keep model warm briefly after use
- prioritize speed over maximum quality


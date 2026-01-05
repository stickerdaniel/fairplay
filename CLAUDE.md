# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FairPlay is an iOS app experiment that renders websites in a WebView and uses on-device LLMs to detect and remove dark patterns from HTML (e.g., making hidden "decline" buttons visible on cookie banners).

## Build & Run

- **Open in Xcode**: `open fairplay.xcodeproj`
- **Build**: Cmd+B in Xcode or `xcodebuild -scheme fairplay -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Run**: Cmd+R in Xcode

## Architecture

- **Platform**: iOS 26.2+, SwiftUI, SwiftData
- **LLM Backend**: [LocalLLMClient](https://github.com/tattn/LocalLLMClient) - supports llama.cpp (GGUF), MLX, and Apple Foundation Models
- **Key Flow**: WebView loads page → Extract HTML via JavaScript → Send to on-device LLM → Inject modified HTML back

## Dependencies

Add Swift packages via Xcode: File → Add Package Dependencies

- **LocalLLMClient**: `https://github.com/tattn/LocalLLMClient`
  - Pinned to commit `ff3a9ee35d6136224aadf9346ded5aad2382a3be` (main branch) for stability
  - Products used: `LocalLLMClient`, `LocalLLMClientFoundationModels`, `LocalLLMClientMLX`
  - Reference docs available at `docs/references/LocalLLMClient/` (git submodule)

### LLM Models Supported

| Model | Backend | Memory | Use Case |
|-------|---------|--------|----------|
| Qwen3 4B | MLX | ~2.75GB | Primary model for dark pattern detection |
| Apple Foundation Models | Native | Built-in | Fastest option, requires iOS 26+ |

## Important Entitlements

For larger models, add to entitlements:
- `com.apple.developer.kernel.increased-memory-limit`

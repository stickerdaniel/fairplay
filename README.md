# FairPlay

An iOS app experiment that uses on-device LLMs to detect and neutralize dark patterns in websites. Browse the web with hidden "decline" buttons revealed, manipulative UI exposed, and deceptive design patterns removed.

## Goals

- **Dark Pattern Detection** - Identify manipulative UI patterns like hidden decline buttons, fake urgency timers, and confusing opt-out flows
- **On-Device Processing** - All analysis runs locally using Apple Foundation Models or MLX - no data leaves your device
- **Real-Time Sanitization** - Extract page HTML, analyze with LLM, inject cleaned HTML back into the WebView

## Limitations

- **Context Window** - this is the biggest limitation. Processing real websites could be possible with optimizations that strip away html bloat and irrelevant markup.
- **Server side blindness** - is the "only 3 left" a dark pattern or are actually only 3 items left?
- **Processing speed" - first step would be to implement a caching system that auto applys fixes on subsequent website visits

## Requirements

- iOS 26.2+
- Xcode 16.0+
- Device with Apple Intelligence or sufficient RAM for local models

## Development Setup

1. Clone the repository
2. Open `fairplay.xcodeproj` in Xcode
3. Add Swift packages via File → Add Package Dependencies:
   - [LocalLLMClient](https://github.com/tattn/LocalLLMClient)
   - [Inject](https://github.com/krzysztofzablocki/Inject.git)
4. Build and run on simulator or device

### Hot Reloading with Inject

This project supports hot reloading via [Inject](https://github.com/krzysztofzablocki/Inject). To enable it:

1. Download [InjectionIII](https://github.com/johnno1962/InjectionIII/releases) and place it in `/Applications`. Use the GitHub release instead of the App Store version.
2. Build and run your app in the simulator

The injection bundle loads automatically. Save any Swift file and changes appear instantly without rebuilding!

## Architecture

```
WebView loads page
       ↓
Extract HTML via JavaScript
       ↓
Send to on-device LLM
       ↓
Inject sanitized HTML back
```

**LLM Backend:** [LocalLLMClient](https://github.com/tattn/LocalLLMClient) provides a unified interface for:
- Apple Foundation Models (on-device)
- llama.cpp with GGUF models
- MLX models

For larger models, add `com.apple.developer.kernel.increased-memory-limit` to your entitlements.

## License

MIT

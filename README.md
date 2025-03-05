# SpeechNote Gemini Corrector

A NixOS Home Manager module that automatically corrects text from the SpeechNote speech-to-text application using Google's Gemini AI.

## Overview

This module sets up a systemd user service that exclusively monitors SpeechNote for speech-to-text output and automatically corrects grammar, punctuation, and structure using Google's Gemini AI. It's specifically designed to work with the SpeechNote application and will not work with other speech-to-text services.

## Features

- Listens for speech-to-text output events from SpeechNote
- Automatically sends the text to Gemini AI for correction
- Places the corrected text back in the clipboard
- Shows desktop notifications during the correction process
- Configurable Gemini model selection
- Runs as a systemd user service

## Prerequisites

- SpeechNote application (this module is designed specifically for SpeechNote and will not work with other speech-to-text tools)
- NixOS with Home Manager
- Wayland compositor (uses wl-clipboard)
- Google Gemini API key

## Installation

### 1. Get a Google AI Studio API Key

To use this module, you need a Google Gemini API key:

1. Visit [Google AI Studio](https://aistudio.google.com/)
2. Create an account if you don't have one
3. Navigate to the API Keys section
4. Create a new API key
5. Save this key to a secure file (e.g., `~/.config/gemini-api-key`)

### 2. Add the Module to Your Home Manager Configuration

Add the following to your `home.nix` or equivalent configuration:

```nix
{ config, pkgs, ... }:

{
  imports = [
    (fetchGit {
      url = "https://github.com/mndfcked/speechnote-gemini-corrector";
      ref = "main";
    })
  ];

  services.speechnote-gemini-corrector = {
    enable = true;
    apiKeyFile = "/path/to/your/gemini-api-key";
    geminiModel = "gemini-2.0-flash-lite"; # Optional, this is the default
  };
}
```

### 3. Apply Your Configuration

Run:

```
home-manager switch
```

## Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `enable` | Enable the service | `false` |
| `apiKeyFile` | Path to file containing Gemini API key | `""` |
| `geminiModel` | Gemini model to use for corrections | `"gemini-2.0-flash-lite"` |

## Compatibility

This module **only works with SpeechNote** and relies on its specific D-Bus interface. It listens for signals from the SpeechNote application and will not work with other speech-to-text applications or services.

## Security Note

Your API key is read from a file rather than being stored directly in the Nix configuration, which is safer as Nix configurations are stored in the Nix store which is world-readable.

## Troubleshooting

- Check the service status with: `systemctl --user status gemini-clipboard-corrector`
- View logs with: `journalctl --user -u gemini-clipboard-corrector`
- Ensure your API key file has the correct permissions and content

## License

MIT
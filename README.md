# deepseek-with-claude-code

Run DeepSeek v4 Pro inside Claude Code on Linux — one install, two commands.

## How it works

A lightweight local proxy sits between Claude Code and the API. It routes `claude deepseek` requests to DeepSeek and all other `claude` sessions to Anthropic as normal. The proxy runs as a systemd user service so it starts automatically.

## Requirements

- Linux with systemd
- Node.js ≥ 18
- [Claude Code](https://claude.ai/code) CLI installed
- DeepSeek API key — get one at [platform.deepseek.com](https://platform.deepseek.com/api_keys)

## Install

```bash
git clone https://github.com/thesegunonakoya/deepseek-with-claude-code.git
cd deepseek-with-claude-code
chmod +x install.sh
./install.sh
```

The installer will prompt you to enter your DeepSeek API key — paste it in when asked. It gets saved to `~/.config/deepseek.env` and is never committed or shared.

Open a new terminal, then:

```bash
claude deepseek   # Claude Code with DeepSeek v4 Pro
claude            # Claude Code normally (Anthropic)
```

## API keys

| Key | Where it's stored |
|-----|-------------------|
| DeepSeek API key | `~/.config/deepseek.env` — set by the installer; update it there anytime |
| Claude / Anthropic key | managed by Claude Code itself (`claude login`) — this tool does not touch it |

## Uninstall

```bash
./install.sh --uninstall
```

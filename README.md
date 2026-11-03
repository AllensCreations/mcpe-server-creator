# MCPE Server Creator

An automated installer script to instantly create a version-controlled Minecraft Bedrock Server template repository on GitHub.

## 🚀 One-Line Installation

Run this command in Termux or any Bash terminal:

```bash
curl -sSL https://raw.githubusercontent.com/AllensCreations/mcpe-server-creator/main/install.sh | bash
```

## 📋 Prerequisites
- **Git** (`pkg install git` / `apt install git`)
- **GitHub CLI** (`pkg install gh` / `apt install gh`) logged in via `gh auth login`

## 📁 What it generates in your new repository
- `behavior_packs/` directory
- `resource_packs/` directory
- `worlds/` directory with `world_behavior_packs.json` & `world_resource_packs.json`
- Optimized `server.properties` ready for Oracle Cloud (50 Players, Hardcore settings)

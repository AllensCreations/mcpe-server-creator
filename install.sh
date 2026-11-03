#!/bin/bash
set -e

echo "=================================================="
echo "    MCPE Server Maker - Automatic Repo Setup      "
echo "=================================================="
echo ""

# Check dependencies
for cmd in git gh; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Error: '$cmd' is required. Please install $cmd before running this script."
        exit 1
    fi
done

# Check GitHub authentication
if ! gh auth status &> /dev/null; then
    echo "❌ You are not logged into GitHub CLI."
    echo "Please run 'gh auth login' first to authenticate."
    exit 1
fi

# Prompt for inputs
read -p "Enter your new Server Repository Name (e.g., my-bedrock-server): " REPO_NAME
if [ -z "$REPO_NAME" ]; then
    echo "❌ Repository name cannot be empty."
    exit 1
fi

read -p "Make this repository Private? (y/n, default: y): " IS_PRIVATE
IS_PRIVATE=${IS_PRIVATE:-y}

if [[ "$IS_PRIVATE" =~ ^[Yy]$ ]]; then
    VISIBILITY="--private"
else
    VISIBILITY="--public"
fi

# Create local temporary working directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo "📂 Generating Bedrock Server template structure..."
mkdir -p "$REPO_NAME"/behavior_packs "$REPO_NAME"/resource_packs "$REPO_NAME"/worlds
cd "$REPO_NAME"

# Create server.properties
cat << 'CONFIG' > server.properties
server-name=My MCPE Server
gamemode=survival
difficulty=hard
force-gamemode=true
max-players=50
online-mode=true
allow-list=false
server-port=19132
server-portv6=19133
view-distance=12
tick-distance=4
player-idle-timeout=30
max-threads=4
CONFIG

# Create pack configuration placeholders
echo "[]" > worlds/world_behavior_packs.json
echo "[]" > worlds/world_resource_packs.json

# Create README for the server repo
cat << CONFIG > README.md
# $REPO_NAME

Minecraft Bedrock Dedicated Server managed via GitHub.

## Folder Structure
- \`behavior_packs/\` - Place unpacked behavior packs here.
- \`resource_packs/\` - Place unpacked resource packs here.
- \`worlds/\` - World data and pack mapping JSON files.
- \`server.properties\` - Server configurations.
CONFIG

# Initialize Git and push using GitHub CLI
git init -b main
git add .
git commit -m "Initial commit: MCPE server template files"

echo "🚀 Creating repository '$REPO_NAME' on your GitHub account..."
gh repo create "$REPO_NAME" $VISIBILITY --source=. --push --remote=origin

# Cleanup local temp files
cd ~
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Success! Your new repository '$REPO_NAME' has been created on GitHub."

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

# Prompt for repository name
read -p "Enter your new Server Repository Name (e.g., my-bedrock-server): " REPO_NAME < /dev/tty
if [ -z "$REPO_NAME" ]; then
    echo "❌ Repository name cannot be empty."
    exit 1
fi

read -p "Make this repository Private? (y/n, default: y): " IS_PRIVATE < /dev/tty
IS_PRIVATE=${IS_PRIVATE:-y}

if [[ "$IS_PRIVATE" =~ ^[Yy]$ ]]; then
    VISIBILITY="--private"
else
    VISIBILITY="--public"
fi

# Ask about Oracle SSH Deployment
read -p "Do you want to configure Oracle Cloud Auto-Deployment via GitHub Actions now? (y/n, default: n): " SETUP_ORACLE < /dev/tty
SETUP_ORACLE=${SETUP_ORACLE:-n}

ORACLE_HOST=""
ORACLE_USER="ubuntu"

if [[ "$SETUP_ORACLE" =~ ^[Yy]$ ]]; then
    read -p "Enter your Oracle VM Public IP Address: " ORACLE_HOST < /dev/tty
    read -p "Enter your Oracle SSH Username (default: ubuntu): " INPUT_USER < /dev/tty
    ORACLE_USER=${INPUT_USER:-ubuntu}
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

# If Oracle setup is chosen, create GitHub Actions workflow directory and file
if [[ "$SETUP_ORACLE" =~ ^[Yy]$ ]]; then
    mkdir -p .github/workflows
    cat << WORKFLOW > .github/workflows/deploy.yml
name: Deploy to Oracle Cloud

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to Oracle VM via SSH
        uses: appleboy/ssh-action@master
        with:
          host: \${{ secrets.ORACLE_HOST }}
          username: \${{ secrets.ORACLE_USER }}
          key: \${{ secrets.ORACLE_SSH_KEY }}
          script: |
            cd /home/$ORACLE_USER/bedrock-server
            git pull origin main
            sudo systemctl restart minecraft
WORKFLOW
    echo "⚙️ Added Oracle GitHub Actions deployment pipeline workflow."
fi

# Create README for the generated server repo
cat << CONFIG > README.md
# $REPO_NAME

Minecraft Bedrock Dedicated Server managed via GitHub and deployed to Oracle Cloud.

## Folder Structure
- \`behavior_packs/\` - Place unpacked behavior packs here.
- \`resource_packs/\` - Place unpacked resource packs here.
- \`worlds/\` - World data and pack mapping JSON files.
- \`server.properties\` - Server configurations.
CONFIG

# Initialize Git and push using GitHub CLI
git init -b main
git add .
git commit -m "Initial commit: MCPE server template and deployment config"

echo "🚀 Creating repository '$REPO_NAME' on your GitHub account..."
gh repo create "$REPO_NAME" $VISIBILITY --source=. --push --remote=origin

# If Oracle setup was chosen, automatically set secrets if values are present
if [[ "$SETUP_ORACLE" =~ ^[Yy]$ ]] && [ -n "$ORACLE_HOST" ]; then
    echo "🔒 Adding Oracle connection details to GitHub Repository Secrets..."
    echo "$ORACLE_HOST" | gh secret set ORACLE_HOST --repo "$REPO_NAME"
    echo "$ORACLE_USER" | gh secret set ORACLE_USER --repo "$REPO_NAME"
    echo "⚠️ Note: You will need to add your SSH Private Key to GitHub Secrets named 'ORACLE_SSH_KEY' for deployments to work."
fi

# Cleanup local temp files
cd ~
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Success! Your new repository '$REPO_NAME' has been created on GitHub."

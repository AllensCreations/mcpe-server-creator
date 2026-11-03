#!/bin/bash
set -e

# Ensure whiptail is available for the UI
if ! command -v whiptail &> /dev/null; then
    echo "Installing required UI package (whiptail)..."
    pkg install -y whiptail || sudo apt-get install -y whiptail
fi

# --- STYLISH TUI MENUS ---
whiptail --title "MCPE Server Maker" --msgbox "Welcome! This tool will create your Minecraft Bedrock server repository on GitHub with automated Oracle Cloud setup workflows." 10 60

# 1. Get Repository Name
REPO_NAME=$(whiptail --title "Repository Name" --inputbox "Enter your new Minecraft server repository name (e.g., my-bedrock-server):" 10 60 3>&1 1>&2 2>&3)
if [ -z "$REPO_NAME" ]; then
    whiptail --title "Cancelled" --msgbox "Repository name cannot be empty. Exiting." 8 40
    exit 1
fi

# 2. Get Visibility Choice
if (whiptail --title "Repository Privacy" --yesno "Do you want this server repository to be PRIVATE? (Recommended)" 10 60); then
    VISIBILITY="--private"
else
    VISIBILITY="--public"
fi

# --- EXECUTION PHASE ---
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

mkdir -p "$REPO_NAME"/behavior_packs "$REPO_NAME"/resource_packs "$REPO_NAME"/worlds "$REPO_NAME"/.github/workflows
cd "$REPO_NAME"

# Base Server Configuration
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

echo "[]" > worlds/world_behavior_packs.json
echo "[]" > worlds/world_resource_packs.json

# --- CREATE AUTOMATED ORACLE SETUP & DEPLOY WORKFLOW ---
cat << 'WORKFLOW' > .github/workflows/oracle-setup.yml
name: Initial Oracle Setup & Server Deploy

on:
  workflow_dispatch:
  push:
    branches: [ main ]

jobs:
  setup-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository Code
        uses: actions/checkout@v4

      - name: Provision & Deploy to Oracle VM via SSH
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.ORACLE_HOST }}
          username: ${{ secrets.ORACLE_USER }}
          key: ${{ secrets.ORACLE_SSH_KEY }}
          script: |
            set -e

            # 1. Update system packages & install dependencies
            sudo apt update && sudo apt install -y git curl unzip screen

            # 2. Create server directory if it doesn't exist
            mkdir -p /home/${{ secrets.ORACLE_USER }}/bedrock-server
            cd /home/${{ secrets.ORACLE_USER }}/bedrock-server

            # 3. If server binaries do not exist, download official Bedrock server
            if [ ! -f "bedrock_server" ]; then
              echo "⬇️ Downloading official Minecraft Bedrock Server..."
              wget https://minecraft.azureedge.net/bin-linux/bedrock-server-1.21.60.10.zip -O bedrock.zip || wget https://minecraft.azureedge.net/bin-linux/bedrock-server-1.21.51.02.zip -O bedrock.zip
              unzip -o bedrock.zip
              rm bedrock.zip
              chmod +x bedrock_server
            fi

            # 4. Clone or update repository files (configs, packs, worlds)
            if [ ! -d ".git" ]; then
              echo "⚙️ Initializing repo sync on Oracle VM..."
              git init -b main
              git remote add origin https://github.com/${{ github.repository }}.git
            fi
            
            git fetch origin main
            git reset --hard origin/main

            # 5. Create 24/7 background systemd service if not present
            if [ ! -f "/etc/systemd/system/minecraft.service" ]; then
              echo "⚙️ Creating systemd service..."
              sudo bash -c "cat << 'SERVICE' > /etc/systemd/system/minecraft.service
[Unit]
Description=Minecraft Bedrock Server
After=network.target

[Service]
User=${{ secrets.ORACLE_USER }}
WorkingDirectory=/home/${{ secrets.ORACLE_USER }}/bedrock-server
ExecStart=/home/${{ secrets.ORACLE_USER }}/bedrock-server/bedrock_server
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE"
              sudo systemctl daemon-reload
              sudo systemctl enable minecraft
            fi

            # 6. Start/Restart the Minecraft server
            echo "🚀 Restarting Minecraft Bedrock Server..."
            sudo systemctl restart minecraft
            echo "✅ Server successfully updated and online!"
WORKFLOW

# --- SERVER REPO README ---
cat << README_EOF > README.md
# $REPO_NAME 🎮

Minecraft Bedrock Dedicated Server managed via GitHub. Automated for zero-terminal Oracle Cloud deployment!

---

## 🚀 How to Provision & Deploy Your Oracle Server (No Terminal Needed!)

### Step 1: Open Oracle UDP Port 19132
1. Log into your **Oracle Cloud Console**.
2. Go to **Compute** > **Instances** > Click your instance name.
3. Click **Primary VNIC** > **Subnet** > **Default Security List**.
4. Click **Add Ingress Rules**:
   - **Source CIDR:** \`0.0.0.0/0\`
   - **IP Protocol:** \`UDP\`
   - **Destination Port Range:** \`19132\`

---

### Step 2: Add Your Oracle Credentials to GitHub Secrets
1. Go to this repository on GitHub -> **Settings** -> **Secrets and variables** -> **Actions**.
2. Add the following **3 Repository Secrets**:
   - **\`ORACLE_HOST\`**: Your Oracle Public IP Address (e.g., \`152.xx.xx.xx\`).
   - **\`ORACLE_USER\`**: Your SSH Username (usually \`ubuntu\`).
   - **\`ORACLE_SSH_KEY\`**: The entire text contents of your downloaded Oracle \`.pem\` private key file.

---

### Step 3: Run the Workflow!
1. Go to the **Actions** tab in this GitHub repository.
2. Select **Initial Oracle Setup & Server Deploy** from the left menu.
3. Click **Run workflow** -> **Run workflow**.

> 💡 **Automatic Sync:** Every time you push new behavior packs, resource packs, or config changes to \`main\`, GitHub Actions will automatically deploy them to your Oracle VM and restart the server!
README_EOF

# Initialize Git and push via GitHub CLI
git init -b main
git add .
git commit -m "Initial commit: MCPE server repo structure and GitHub Actions Oracle setup workflow"

gh repo create "$REPO_NAME" $VISIBILITY --source=. --push --remote=origin

cd ~
rm -rf "$TEMP_DIR"

whiptail --title "Success!" --msgbox "Repository '$REPO_NAME' created! Just add your 3 GitHub Secrets (ORACLE_HOST, ORACLE_USER, ORACLE_SSH_KEY) and trigger the Actions workflow to build your Oracle server automatically!" 12 60

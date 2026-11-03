#!/bin/bash
set -e

# Ensure whiptail is available for the UI
if ! command -v whiptail &> /dev/null; then
    echo "Installing required UI package (whiptail)..."
    pkg install -y whiptail || sudo apt-get install -y whiptail
fi

# --- STYLISH TUI MENUS ---
whiptail --title "MCPE Server Maker" --msgbox "Welcome! This tool will create a fully configured, production-ready Minecraft Bedrock server repository on your GitHub, complete with Oracle Cloud deployment support." 10 60

# 1. Get Repository Name
REPO_NAME=$(whiptail --title "Repository Name" --inputbox "Enter your new Minecraft server repository name (e.g., my-bedrock-server):" 10 60 3>&1 1>&2 2>&3)
if [ -z "$REPO_NAME" ]; then
    whiptail --title "Cancelled" --msgbox "Repository name cannot be empty. Exiting." 8 40
    exit 1
fi

# 2. Get Visibility Choice
if (whiptail --title "Repository Privacy" --yesno "Do you want this server repository to be PRIVATE? (Recommended for safety)" 10 60); then
    VISIBILITY="--private"
else
    VISIBILITY="--public"
fi

# 3. Oracle Setup Choice
if (whiptail --title "Oracle Cloud Integration" --yesno "Do you want to automatically set up Oracle Cloud Auto-Deployment via GitHub Actions?" 10 60); then
    SETUP_ORACLE="y"
    ORACLE_HOST=$(whiptail --title "Oracle Configuration" --inputbox "Enter your Oracle VM Public IP Address:" 10 60 3>&1 1>&2 2>&3)
    ORACLE_USER=$(whiptail --title "Oracle Configuration" --inputbox "Enter your Oracle SSH Username (default: ubuntu):" 10 60 ubuntu 3>&1 1>&2 2>&3)
    ORACLE_USER=${ORACLE_USER:-ubuntu}
else
    SETUP_ORACLE="n"
fi

# --- EXECUTION PHASE ---
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

mkdir -p "$REPO_NAME"/behavior_packs "$REPO_NAME"/resource_packs "$REPO_NAME"/worlds
cd "$REPO_NAME"

# Server configuration
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

# If Oracle was selected, build the GitHub Actions deploy pipeline
if [ "$SETUP_ORACLE" = "y" ]; then
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
fi

# --- BUILT-IN "HOW-TO" README FOR THE SERVER ---
cat << README_EOF > README.md
# $REPO_NAME 🎮

Welcome to your automated Minecraft Bedrock Dedicated Server repository! 

---

## 📖 Complete Guide: Setting up Oracle Cloud & Connecting Your Server

### Step 1: Create Your Oracle Cloud Free Tier Instance
1. Log into your **Oracle Cloud Console**.
2. Go to **Compute** > **Instances** > click **Create Instance**.
3. Name your instance and select **Ubuntu** (latest LTS) as the Image.
4. Under **Shape**, click **Change Shape**, select **Ampere** (ARM), and configure up to 4 OCPUs and 24 GB RAM (Always Free tier limits).
5. Under **Networking**, ensure **Assign a public IPv4 address** is checked.
6. Under **Add SSH keys**, choose **Save private key** and download your `.pem` file to your device. Click **Create**.

---

### Step 2: Open Port 19132 (Crucial for Players to Join)
By default, Oracle blocks incoming traffic. You must open the Minecraft port:
1. In your instance page, click your **Primary VNIC** / **Subnet** link.
2. Click on the **Default Security List**.
3. Click **Add Ingress Rules**:
   - **Source CIDR:** \`0.0.0.0/0\`
   - **IP Protocol:** \`UDP\`
   - **Destination Port Range:** \`19132\`
4. Click **Add Ingress Rule**.

---

### Step 3: Find Your Public Oracle IP
1. Go back to **Compute** > **Instances** and click your running server name.
2. Look under **Primary VNIC** -> **Public IP address**. Copy this IP (e.g., \`152.xx.xx.xx\`). This is your Oracle Public IP!

---

### Step 4: Initial Server Setup via SSH
Open your terminal (Termux or PC) and connect to your Oracle VM using your private key and public IP:
\`\`\`bash
ssh -i /path/to/your-key.pem ubuntu@YOUR_ORACLE_IP
\`\`\`

Run these commands inside Oracle to install dependencies and clone this repo:
\`\`\`bash
sudo apt update && sudo apt install -y git curl unzip screen
cd /home/ubuntu
git clone https://github.com/\$(gh api user -q .login)/$REPO_NAME.git bedrock-server
cd bedrock-server

# Download official Bedrock server software
wget https://minecraft.azureedge.net/bin-linux/bedrock-server-*.zip -O bedrock.zip
unzip bedrock.zip
rm bedrock.zip
\`\`\`

---

### Step 5: Set up 24/7 Background Service (\`systemd\`)
Create a background daemon so your server runs continuously even when you close SSH:
\`\`\`bash
sudo nano /etc/systemd/system/minecraft.service
\`\`\`
Paste this configuration:
\`\`\`ini
[Unit]
Description=Minecraft Bedrock Server
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/bedrock-server
ExecStart=/home/ubuntu/bedrock-server/bedrock_server
Restart=always

[Install]
WantedBy=multi-user.target
\`\`\`
Save and exit (Ctrl+O, Enter, Ctrl+X), then start the service:
\`\`\`bash
sudo systemctl daemon-reload
sudo systemctl enable minecraft
sudo systemctl start minecraft
\`\`\`

---

### Step 6: Enable Auto-Deploy (GitHub Secrets)
To let GitHub auto-update your Oracle server whenever you push changes:
1. Go to your repository on GitHub -> **Settings** -> **Secrets and variables** -> **Actions**.
2. Add a new repository secret named **\`ORACLE_SSH_KEY\`** containing the **entire text contents** of your Oracle private SSH key file (`.pem`).
README_EOF

# Initialize Git and push via GitHub CLI
git init -b main
git add .
git commit -m "Add full step-by-step Oracle cloud setup instructions to generated server README"

# Create the repo on GitHub using gh
gh repo create "$REPO_NAME" $VISIBILITY --source=. --push --remote=origin

# Automatically push secrets if Oracle config was provided
if [ "$SETUP_ORACLE" = "y" ] && [ -n "$ORACLE_HOST" ]; then
    echo "$ORACLE_HOST" | gh secret set ORACLE_HOST --repo "$REPO_NAME"
    echo "$ORACLE_USER" | gh secret set ORACLE_USER --repo "$REPO_NAME"
fi

cd ~
rm -rf "$TEMP_DIR"

whiptail --title "Success!" --msgbox "Your repository '$REPO_NAME' has been successfully created with the full Oracle setup guide inside its README!" 10 60

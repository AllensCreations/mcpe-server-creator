# MCPE Server Creator

An automated installer script to instantly create a version-controlled Minecraft Bedrock Server template repository on GitHub, ready for Oracle Cloud.

## 🚀 How to Run

Download and run the installer interactively in Termux:

```bash
curl -sSL https://raw.githubusercontent.com/AllensCreations/mcpe-server-creator/main/install.sh -o install.sh && bash install.sh && rm install.sh
```

## ☁️ Oracle Cloud Integration
When running the script, you can now choose to **automatically configure Oracle Cloud Auto-Deployment**. 
- It will create a GitHub Actions workflow ().
- Every time you push a resource pack or change settings on GitHub, it auto-syncs to your Oracle VM and restarts the server!

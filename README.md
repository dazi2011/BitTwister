# 📂 BitTwister — File Corruption Tool for macOS

**BitTwister** is a macOS-native utility designed for safe file corruption testing.  
It allows users to **simulate data loss** by generating corrupted copies of files using various customizable methods — useful for recovery testing, file resilience verification, and educational experiments.

---

## 🛠 Features

- Drag & drop files or folders to create corrupted copies instantly
- 5 built-in corruption strategies:
  - Bitwise Flip
  - Random Byte Overwrite
  - Zero Fill
  - Byte Reversal
  - Bit Shift
- Supports custom output location & “keep original” toggle
- Language switch: English / Simplified Chinese
- Selectable themes: Light / Dark / System
- Toggleable detailed logs with persistent history and size limit
- Preferences remembered between sessions

---

## ⚠️ Disclaimer

BitTwister **does not modify original files** by default — only corrupted **copies** are generated.

However, this tool **intentionally corrupts data**, and certain experimental options (in developer builds) may lead to **irreversible file damage** or data loss.

> **Use at your own risk. The authors take no responsibility for data loss or hardware damage. Always test in a safe environment.**

---

## 🚀 How to Use

### ✅ Option 1: Download Prebuilt App

Visit the [GitHub Releases page](https://github.com/dazi2011/BitTwister/releases) to download the latest `.zip` package.  
After downloading:

1. Unzip the archive
2. Move `BitTwister.app` to your `/Applications` folder
3. Right-click and choose **“Open”** on first launch (bypasses macOS Gatekeeper for unsigned apps)

### 🔧 Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/dazi2011/BitTwister.git
cd BitTwister

# Open in Xcode and build
open BitTwister.xcodeproj

# 📂 BitTwister — File Corruption & Recovery Toolkit for macOS

**BitTwister** is a macOS‑native utility that lets you **deliberately corrupt** and now also **attempt to recover** files in a controlled, repeatable way. It is aimed at QA engineers, data‑recovery professionals, educators and anybody who needs to study how software behaves when data goes bad.

---

## 🛠 Feature Highlights

| Category            | Highlights                                                                                                                                                                                                                                         |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Corruption Mode** | • Five built‑in strategies (see below)<br>• *Keep original* toggle<br>• Custom output path<br>• Batch drag‑&‑drop **or** *Upload Files* button                                                                                                     |
| **Recovery Mode**   | • Drag, drop **or** upload damaged files for automated repair<br>• Multiple header‑repair algorithms (PNG, JPEG, ZIP, PDF, bitwise‑flip …)<br>• *Replace original after recovery* toggle<br>• Safe‑write to alternate path when overwriting is off |
| **User Experience** | • English / 简体中文 UI<br>• Light / Dark / System themes<br>• Persistent preferences<br>• Detailed, filterable logs with size cap                                                                                                                     |
| **Safety**          | • Corruption acts on *copies* by default<br>• Recovery asks for confirmation and warns of possible secondary damage                                                                                                                                |

---

## 🔄 Corruption Strategies

| Strategy                  | What it does                             | Typical use‑case                       |
| ------------------------- | ---------------------------------------- | -------------------------------------- |
| **Bitwise Flip**          | XOR `0xFF` over the first *n* bytes      | Simulate electromagnetic faults        |
| **Random Byte Overwrite** | Replace scattered bytes with random data | Test robustness against bit‑rot        |
| **Zero Fill**             | Zeroes out the header region             | Quickly invalidate most file headers   |
| **Byte Reversal**         | Reverse the order of selected blocks     | Stress‑test parser alignment           |
| **Bit Shift**             | Circular shift bits left / right         | Examine decoder tolerance to bit drift |

All strategies are non‑destructive when *Keep original* is enabled.

---

## 🩺 Recovery Mode (since v1.1.0)

1. **Select input**   Drag files *or* click **Upload Files**.
2. **Acknowledge risk**   A warning dialog reminds you that a failed repair can make things worse.
3. **Automatic analysis**   BitTwister inspects file signatures and tries a chain of repair strategies:
   • header restoration (magic‑number fix) for PNG / JPEG / ZIP / PDF
   • bitwise *un‑flip* when the header looks inverted
   • 0xFF padding when the header is completely zeroed
   • plug‑in hooks for custom strategies.
4. **Output handling**   Depending on settings the repaired file is either
   • written back to the **original location** (if *Replace original* is on),
   • stored in a user‑selected **Recovery Path**, or
   • saved as `recovered_<filename>` next to the source.
5. **Result banner**   You will see one of: **✅ Recovered**, **ℹ️ Not corrupted**, **❌ Failed**.

---

## 🚀 Getting Started

### Option A  ·  Pre‑built Binary

1. Download the latest **Zip** from the [Releases page](https://github.com/dazi2011/BitTwister/releases).
2. Unzip and move **BitTwister.app** to `/Applications`.
3. On first launch *right‑click → Open* to bypass Gatekeeper.

### Option B  ·  Build from Source

```bash
# Clone & build
 git clone https://github.com/dazi2011/BitTwister.git
 cd BitTwister
 open BitTwister.xcodeproj   # Xcode 15+
```

---




## 🤝 Contributing

Pull requests are welcome — especially for new corruption or recovery strategies.
See `CONTRIBUTING.md` for style guidelines.

---

## 📝 License

Released under the **MIT License**.  See `LICENSE` for details.

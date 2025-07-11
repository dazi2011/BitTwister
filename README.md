📂 BitTwister — File Corruption & Recovery Toolkit for macOS

BitTwister is a macOS-native utility that lets you deliberately corrupt and now also attempt to recover files in a controlled, repeatable way. It is aimed at QA engineers, data-recovery professionals, educators, and anyone who needs to study how software behaves when data goes bad.

⸻

🛠 Feature Highlights

Category	Highlights
Corruption Mode	• Five built-in strategies (see below)• Keep original toggle• Custom output path• Batch drag-&-drop or Upload button
Recovery Mode	• Drag, drop or upload damaged files for automated repair• Multiple header-repair algorithms (PNG, JPEG, ZIP, PDF, bitwise-flip, etc.)• “Replace original after recovery” toggle• Safe-write to alternate path when overwriting is off
User Experience	• English / 简体中文 UI• Light / Dark / System themes• Persistent preferences• Detailed, filterable logs with size cap
Safety	• Corruption acts on copies by default• Recovery mode prompts a risk warning before acting


⸻

🔄 Corruption Strategies (Pro Edition)

Strategy	What It Does	Typical Use-Case
Bitwise Flip	XOR 0xFF over the first n bytes	Simulate random electromagnetic faults
Random Byte Overwrite	Replace scattered bytes with random data	Test robustness against partial rot
Zero Fill	Zeroes out specified header region	Quickly kill most file headers
Byte Reversal	Reverse order of selected blocks	Stress-test parser alignment
Bit Shift	Circular shift bits left/right	Examine decoder tolerance to bit drift

All strategies are non-destructive when Keep Original is ON.

⸻

🩺 Recovery Mode (NEW in 1.1.0)
	1.	Choose Input   Drag files or click Upload Files to pick from Finder.
	2.	Acknowledge Risk   A warning alert reminds you that recovery could worsen damage.
	3.	Automatic Analysis   BitTwister inspects file signatures, applies a heuristic chain:
	•	Header restoration (magic-number repair) for PNG, JPEG, ZIP, PDF …
	•	Bitwise un-flip when header appears inverted
	•	0xFF padding for fully-zeroed headers
	•	Future plug-in algorithms via Swift protocols
	4.	Output Handling
	•	Replace Original ON → writes directly back to the source file (use with caution).
	•	Otherwise writes to either a user-selected Recovery Path or recovered_<filename> next to the input.
	5.	Result Banner   A status line shows ✅ Recovered, ℹ️ Not Corrupted, or ❌ Failed.

Professional Tip ▸ All write operations are dispatched on a background queue and wrapped in do { try … } catch { … } so a single failure never crashes the GUI.

⸻

🧑‍💻 Under the Hood

Layer	Tech Notes
UI	SwiftUI + @AppStorage for instant settings persistence
Concurrency	Repair/corruption jobs run on a DispatchQueue(qos: .userInitiated) to keep the main thread fluid
Signature Detection	Lightweight UTType + custom magic number matcher supporting extension-agnostic checks
Pluggability	Add a new CorruptionMethod or RecoveryStrategy by conforming to a protocol and dropping a file into the Strategies group


⸻

⚠️ Disclaimer

BitTwister is a destructive-testing tool.
	•	Even with Keep Original ON, poor recovery attempts may still harm data if you later overwrite the originals.
	•	Always work on backups or expendable copies.
	•	The authors are not liable for data loss, hardware damage, or existential dread.

⸻

🚀 Getting Started

Option A  ·  Pre-Built Binary
	1.	Download the latest .zip from Releases.
	2.	Unzip, move BitTwister.app to /Applications.
	3.	On first launch, Right-click → Open to bypass Gatekeeper.

Option B  ·  Build from Source

# Clone & build
 git clone https://github.com/dazi2011/BitTwister.git
 cd BitTwister
 open BitTwister.xcodeproj   # Xcode 15+


⸻

📄 Changelog (excerpt)

1.1.0 – 2025-07-11
	•	Recovery Mode upload + confirmation alert
	•	New settings sections for corruption & recovery paths
	•	Bold section headers for better readability
	•	Under-the-hood: safer write routing, richer log filtering

⸻

🤝 Contributing

Pull requests are welcome — especially for new corruption/recovery strategies.
Please read CONTRIBUTING.md for coding guidelines and branch workflow.

⸻

📝 License

This project is licensed under the MIT License.  See LICENSE for details.

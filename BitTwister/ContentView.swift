import SwiftUI
import UniformTypeIdentifiers
import AppKit
import Combine

enum ThemeOption: String, CaseIterable, Identifiable {
    case system = "System"
    case light  = "Light"
    case dark   = "Dark"
    var id: String { rawValue }
    var zh: String {
        switch self { case .system: return "跟随系统"; case .light: return "白色"; case .dark: return "黑色" }
    }
}

enum Language: String, CaseIterable, Identifiable {
    case chinese = "中文"
    case english = "English"
    var id: String { rawValue }
}

enum CorruptionMethod: String, CaseIterable, Identifiable {
    case headerFlip   = "Header Flip"        // 按位取反
    case randomBytes  = "Random Bytes"       // 随机字节
    case zeroFill     = "Zero Fill"          // 全 0
    case reverseBytes = "Reverse Bytes"      // 字节顺序反转
    case bitShiftLeft = "Bit‑Shift Left"     // 字节左移 1 位
    case overwriteAll = "Overwrite All"      // 全部用随机字节覆盖（不可恢复）
    var id: String { rawValue }
}

enum LogKind: String, CaseIterable, Identifiable {
    case info   = "Info"
    case warning = "Warning"
    case error  = "Error"
    case debug  = "Debug"
    case success = "Success"
    case silent = "Silent"
    var id: String { rawValue }
    var zh: String {
        switch self {
        case .info:    return "信息"
        case .warning: return "警告"
        case .error:   return "错误"
        case .debug:   return "调试"
        case .success: return "成功"
        case .silent:  return "静默"
        }
    }
}

fileprivate func loc(_ zh: String, _ en: String, _ lang: Language) -> String {
    lang == .chinese ? zh : en
}

struct ContentView: View {
    @State private var selectedTab: Int = 0
    private var tabInfo: [(String, String)] {
        [
            (loc("常规", "General", language), "gearshape"),
            (loc("高级", "Advanced", language), "slider.horizontal.3"),
            (loc("关于", "About", language), "info.circle")
        ]
    }
    @State private var corruptedFiles: [String] = []
    @State private var isHovering = false
    @State private var showAlert = false
    @State private var pendingURLs: [URL] = []
    @State private var showFileImporter: Bool = false
    @State private var isRecoveryMode: Bool = false

    @AppStorage("keepOriginal") private var keepOriginal: Bool = true
    @AppStorage("language")     private var languageRaw: String = Language.chinese.rawValue
    @AppStorage("corruption")   private var corruptionRaw: String = CorruptionMethod.headerFlip.rawValue
    @AppStorage("destPath")     private var destinationPath: String = ""
    @AppStorage("logLimit") private var logLimit: Int = 500        // max lines kept
    @AppStorage("logs")      private var logsRaw: String = ""      // lines joined by \n
    @AppStorage("theme") private var themeRaw: String = ThemeOption.system.rawValue
    @AppStorage("recoveryPath")    private var recoveryPath: String = ""
    @AppStorage("replaceCorrupted") private var replaceCorrupted: Bool = false
    private var recoveryDestinationURL: URL? {
        get { recoveryPath.isEmpty ? nil : URL(fileURLWithPath: recoveryPath) }
        set { recoveryPath = newValue?.path ?? "" }
    }
    private var recoveryURLBinding: Binding<URL?> {
        Binding(
            get: { recoveryDestinationURL },
            set: { newVal in recoveryPath = newVal?.path ?? "" }
        )
    }

    private var language: Language {
        get { Language(rawValue: languageRaw) ?? .chinese }
        set { languageRaw = newValue.rawValue }
    }
    private var corruptionMethod: CorruptionMethod {
        get { CorruptionMethod(rawValue: corruptionRaw) ?? .headerFlip }
        set { corruptionRaw = newValue.rawValue }
    }
    private var destinationURL: URL? {
        get { destinationPath.isEmpty ? nil : URL(fileURLWithPath: destinationPath) }
        set { destinationPath = newValue?.path ?? "" }
    }

    private var themeOption: ThemeOption {
        get { ThemeOption(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }

    private var destURLBinding: Binding<URL?> {
        Binding(
            get: { destinationURL },
            set: { newVal in destinationPath = newVal?.path ?? "" }
        )
    }

    // Bindings to avoid "self is immutable" in view builder
    private var languageBinding: Binding<Language> {
        Binding(
            get: { language },
            set: { newVal in languageRaw = newVal.rawValue }
        )
    }
    private var corruptionBinding: Binding<CorruptionMethod> {
        Binding(
            get: { corruptionMethod },
            set: { newVal in corruptionRaw = newVal.rawValue }
        )
    }

    @State private var showSettings: Bool = false
    @State private var logs: [String] = []
    @State private var showLogs: Bool = false
    // Recovery‑mode upload helper state
    @State private var showFileImporterRecovery: Bool = false
    @State private var pendingRecoveryURLs: [URL] = []
    @State private var showRecoveryAlert: Bool = false

    var body: some View {
        Group {
            HStack {
                Button(action: { isRecoveryMode.toggle() }) {
                    HStack {
                        Image(systemName: isRecoveryMode ? "hammer" : "bandage")
                        Text(isRecoveryMode
                             ? (language == .chinese ? "切换到破坏模式" : "Switch to Corruption Mode")
                             : (language == .chinese ? "进入恢复模式" : "Enter Recovery Mode"))
                    }
                }
                .padding(.top)
                Spacer()
            }
            .padding(.horizontal)

            if isRecoveryMode {
                VStack {
                    Text(language == .chinese ? "恢复模式" : "Recovery Mode")
                        .font(.largeTitle)
                        .padding()

                    Text(language == .chinese
                         ? "拖入损坏文件，我将尝试检测并修复"
                         : "Drop corrupted files here and I will try to repair them")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button(language == .chinese ? "上传文件" : "Upload Files") {
                        showFileImporterRecovery = true
                    }
                    .padding(.horizontal)
                    .fileImporter(
                        isPresented: $showFileImporterRecovery,
                        allowedContentTypes: [UTType.item],
                        allowsMultipleSelection: true
                    ) { result in
                        switch result {
                        case .success(let urls):
                            pendingRecoveryURLs = urls
                            showRecoveryAlert = true
                        case .failure(let error):
                            appendLog(.error, "❌ Recovery file selection failed: \(error.localizedDescription)")
                        }
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isHovering ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                            .frame(width: 360, height: 180)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isHovering ? Color.accentColor : Color.gray, lineWidth: 2)
                            )

                        VStack {
                            Image(systemName: "arrow.clockwise.icloud")
                                .font(.system(size: 40))
                                .padding(.bottom, 5)
                            Text(language == .chinese ? "拖放文件到此处" : "Drag files here")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .onDrop(of: [.fileURL], isTargeted: $isHovering) { providers in
                        // Only handle drop if in recovery mode
                        if isRecoveryMode {
                            handleRecoveryDrop(providers: providers)
                        }
                        return true
                    }

                    // Only show result if in recovery mode and result is from recovery
                    if let lastPath = corruptedFiles.last, isRecoveryMode {
                        // Only display if the last result is a recovery result (contains "修复" or "Recovered")
                        if  lastPath.contains("修复")
                            || lastPath.contains("Recovered")
                            || lastPath.contains("Failed")
                            || lastPath.contains("未损坏")
                            || lastPath.contains("File is not corrupted")
                            || lastPath.contains("not corrupted") {
                            Text((language == .chinese ? "最近处理结果: " : "Last result: ") + lastPath)
                                .font(.headline)
                                .padding(.top, 4)
                        }
                    }

                    Spacer()
                }
            } else {
                VStack {
                    if language == .chinese {
                        Text("文件损坏器")
                            .font(.largeTitle)
                            .padding(.top)

                        Text("拖入文件或文件夹，程序将复制副本并依照您设置的方式对文件进行破坏")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("上传文件") {
                            showFileImporter = true
                        }
                        .padding(.horizontal)
                        .fileImporter(
                            isPresented: $showFileImporter,
                            allowedContentTypes: [UTType.item],
                            allowsMultipleSelection: true
                        ) { result in
                            switch result {
                            case .success(let urls):
                                pendingURLs = urls
                                isHovering = false
                                showAlert = true
                            case .failure(let error):
                                print("文件选择失败: \(error.localizedDescription)")
                            }
                        }

                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isHovering ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                                .frame(width: 360, height: 180)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isHovering ? Color.accentColor : Color.gray, lineWidth: 2)
                                )

                            VStack {
                                Image(systemName: "doc.badge.xmark")
                                    .font(.system(size: 40))
                                    .padding(.bottom, 5)
                                Text("拖放文件或文件夹到此处")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .onDrop(of: [.fileURL], isTargeted: $isHovering) { providers in
                            // Only handle drop if not in recovery mode
                            if !isRecoveryMode {
                                handleDrop(providers: providers)
                            }
                            return true
                        }

                        // Only show result if not in recovery mode and it's a corruption result
                        if let lastPath = corruptedFiles.last, !isRecoveryMode {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(
                                    (language == .chinese ? "已生成损坏文件副本: " : "Corrupted copy generated: ")
                                    + "(\(lastPath))"
                                )
                                .font(.headline)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            }
                            .padding(.top, 4)
                        }

                        Spacer()

                        Text("⚠️ 此操作有风险，后果请自行承担")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.bottom)
                    } else {
                        Text("File Corruption Testing Tool")
                            .font(.largeTitle)
                            .padding(.top)

                        Text("Drag files or folders here. The program will copy the items and corrupt them according to your chosen method.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Upload Files") {
                            showFileImporter = true
                        }
                        .padding(.horizontal)
                        .fileImporter(
                            isPresented: $showFileImporter,
                            allowedContentTypes: [UTType.item],
                            allowsMultipleSelection: true
                        ) { result in
                            switch result {
                            case .success(let urls):
                                pendingURLs = urls
                                isHovering = false
                                showAlert = true
                            case .failure(let error):
                                print("File selection failed: \(error.localizedDescription)")
                            }
                        }

                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isHovering ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                                .frame(width: 360, height: 180)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isHovering ? Color.accentColor : Color.gray, lineWidth: 2)
                                )

                            VStack {
                                Image(systemName: "doc.badge.xmark")
                                    .font(.system(size: 40))
                                    .padding(.bottom, 5)
                                Text("Drag files or folders here")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .onDrop(of: [.fileURL], isTargeted: $isHovering) { providers in
                            // Only handle drop if not in recovery mode
                            if !isRecoveryMode {
                                handleDrop(providers: providers)
                            }
                            return true
                        }

                        // Only show result if not in recovery mode and it's a corruption result
                        if let lastPath = corruptedFiles.last, !isRecoveryMode {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(
                                    (language == .chinese ? "已生成损坏文件副本: " : "Corrupted copy generated: ")
                                    + "(\(lastPath))"
                                )
                                .font(.headline)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            }
                            .padding(.top, 4)
                        }

                        Spacer()

                        Text("⚠️ All operations are performed on copies only, original files are not modified.")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.bottom)
                    }
                }
            }
        }
        .preferredColorScheme({
            switch themeOption {
            case .light:  return .light
            case .dark:   return .dark
            default:      return nil
            }
        }())
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button(action: { showLogs = true }) {
                    Image(systemName: "doc.text.magnifyingglass")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                destinationURL: destURLBinding,
                keepOriginal: $keepOriginal,
                language: languageBinding,
                corruptionMethod: corruptionBinding,
                themeOption: Binding(
                    get: { themeOption },
                    set: { newVal in themeRaw = newVal.rawValue }
                ),
                recoveryDestinationURL: recoveryURLBinding,
                replaceCorrupted: $replaceCorrupted,
                isRecoveryMode: isRecoveryMode
            )
        }
        .sheet(isPresented: $showLogs) {
            LogView(language: language, logs: logs)
        }
        .alert(isPresented: $showRecoveryAlert) {
            Alert(
                title: Text(language == .chinese ? "风险提示" : "Risk Warning"),
                message: Text(
                    language == .chinese
                    ? "修复过程中如遇异常，可能对文件造成二次损伤。是否继续？"
                    : "If the repair fails unexpectedly, the file may suffer further damage. Continue?"
                ),
                primaryButton: .destructive(Text(language == .chinese ? "继续修复" : "Proceed")) {
                    pendingRecoveryURLs.forEach { attemptRecovery(for: $0) }
                    pendingRecoveryURLs.removeAll()
                },
                secondaryButton: .cancel(Text(language == .chinese ? "取消" : "Cancel")) {
                    pendingRecoveryURLs.removeAll()
                }
            )
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(language == .chinese ? "确认操作" : "Confirm Operation"),
                message: Text(language == .chinese ? "是否确认对所选文件/文件夹的副本进行破坏？" : "Are you sure to corrupt copies of the selected files/folders?"),
                primaryButton: .destructive(Text(language == .chinese ? "确认" : "Confirm")) {
                    processURLs(pendingURLs)
                },
                secondaryButton: .cancel(Text(language == .chinese ? "取消" : "Cancel"))
            )
        }
        .onAppear {
            logs = logsRaw.isEmpty ? [] : logsRaw.components(separatedBy: "\n")
        }
    }
@AppStorage("enabledLogKindsRecovery") private var enabledLogKindsRecovery: String = "Info,Warning,Error,Debug,Success"
@AppStorage("enabledLogKindsCorrupt") private var enabledLogKindsCorrupt: String = "Info,Warning,Error,Debug,Success"

private var enabledKindsRaw: String {
    get { isRecoveryMode ? enabledLogKindsRecovery : enabledLogKindsCorrupt }
    set {
        if isRecoveryMode {
            enabledLogKindsRecovery = newValue
        } else {
            enabledLogKindsCorrupt = newValue
        }
    }
}

private var enabledKinds: Set<LogKind> {
    get { Set(enabledKindsRaw.split(separator: ",").compactMap { LogKind(rawValue: String($0)) }) }
    set { enabledKindsRaw = newValue.map(\.rawValue).joined(separator: ",") }
}

private func shouldLog(_ kind: LogKind) -> Bool {
    guard kind != .silent else { return false }
    return enabledKinds.contains(kind)
}

    private func appendLog(_ kind: LogKind, _ line: String) {
        guard shouldLog(kind) else { return }
        logs.append(line)
        if logs.count > logLimit { logs.removeFirst(logs.count - logLimit) }
        logsRaw = logs.joined(separator: "\n")
    }

    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                if let data = data as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.pendingURLs = urls
            self.isHovering = false
            self.showAlert = true
        }
    }

    private func processURLs(_ urls: [URL]) {
        DispatchQueue.global(qos: .userInitiated).async {
            for url in urls {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        corruptFolder(at: url)
                    } else {
                        corruptFile(at: url)
                    }
                }
            }
            DispatchQueue.main.async {
                self.pendingURLs.removeAll()
            }
        }
    }

    private func corruptFile(at url: URL, outputDir: URL? = nil) {
        let headerSize = 256
        do {
            let fileData = try Data(contentsOf: url)
            let prefix = fileData.prefix(headerSize)
            // Move corruptedData and suffix outside switch
            var corruptedData: Data
            var suffix = fileData.dropFirst(headerSize)
            let corruptedPrefix: Data
            switch corruptionMethod {
            case .headerFlip:
                corruptedPrefix = Data(prefix.map { ~$0 })
                corruptedData = Data()
                corruptedData.append(corruptedPrefix)
                corruptedData.append(suffix)
            case .randomBytes:
                corruptedPrefix = Data((0..<prefix.count).map { _ in UInt8.random(in: 0...255) })
                corruptedData = Data()
                corruptedData.append(corruptedPrefix)
                corruptedData.append(suffix)
            case .zeroFill:
                corruptedPrefix = Data(repeating: 0, count: prefix.count)
                corruptedData = Data()
                corruptedData.append(corruptedPrefix)
                corruptedData.append(suffix)
            case .reverseBytes:
                corruptedPrefix = Data(prefix.reversed())
                corruptedData = Data()
                corruptedData.append(corruptedPrefix)
                corruptedData.append(suffix)
            case .bitShiftLeft:
                corruptedPrefix = Data(prefix.map { $0 << 1 })
                corruptedData = Data()
                corruptedData.append(corruptedPrefix)
                corruptedData.append(suffix)
            case .overwriteAll:
                corruptedPrefix = Data((0..<fileData.count).map { _ in UInt8.random(in: 0...255) })
                corruptedData = corruptedPrefix // 覆盖整个文件内容
                suffix = Data() // 清空后缀
            }
            let base = outputDir ?? (
                keepOriginal
                ? (destinationURL ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"))
                : url.deletingLastPathComponent()
            )
            let outputURL = base.appendingPathComponent("corrupted_" + url.lastPathComponent)
            try corruptedData.write(to: outputURL)
            DispatchQueue.main.async {
                corruptedFiles.append(outputURL.path)
                appendLog(.success, "✅ \(outputURL.path)")
            }
        } catch {
            DispatchQueue.main.async {
                corruptedFiles.append("❌ " + (language == .chinese ? "错误: " : "Error: ") + error.localizedDescription)
                appendLog(.error, "❌ \(error.localizedDescription)")
            }
        }
    }

    private func corruptFolder(at url: URL) {
        appendLog(.info, "📂 Scanning folder: \(url.path)")
        let fileManager = FileManager.default
        do {
            let outputBase = destinationURL ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
            let outputFolder = outputBase.appendingPathComponent("corrupted_" + url.lastPathComponent)
            try? fileManager.createDirectory(at: outputFolder, withIntermediateDirectories: true)

            func traverseAndCorrupt(from base: URL, to outputBase: URL) throws {
                let contents = try fileManager.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                for item in contents {
                    let values = try item.resourceValues(forKeys: [.isDirectoryKey])
                    if values.isDirectory == true {
                        let subdir = outputBase.appendingPathComponent(item.lastPathComponent)
                        try? fileManager.createDirectory(at: subdir, withIntermediateDirectories: true)
                        try traverseAndCorrupt(from: item, to: subdir)
                    } else {
                        corruptFile(at: item, outputDir: outputBase)
                    }
                }
            }

            try traverseAndCorrupt(from: url, to: outputFolder)
        } catch {
            print("❌ 处理文件夹失败: \(error.localizedDescription)")
        }
    }

    // 恢复模式拖放处理
    private func handleRecoveryDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                if let data = data as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            for url in urls {
                attemptRecovery(for: url)
            }
        }
    }

    /// 简单根据扩展名判断常见文件的 magic number 是否匹配
    private func headerMatches(_ header: Data, ext: String) -> Bool {
        let bytes = [UInt8](header)
        switch ext.lowercased() {
        case "png":
            // 89 50 4E 47
            return bytes.starts(with: [0x89, 0x50, 0x4E, 0x47])
        case "jpg", "jpeg":
            // FF D8 FF
            return bytes.starts(with: [0xFF, 0xD8, 0xFF])
        case "zip":
            // 50 4B
            return bytes.starts(with: [0x50, 0x4B])
        case "pdf":
            // 25 50 44 46
            return bytes.starts(with: [0x25, 0x50, 0x44, 0x46])
        default:
            return false
        }
    }

    private func attemptRecovery(for url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let headerSize = 256
            do {
                let originalData = try Data(contentsOf: url)
                // 获取恢复前的UTType
                let preType = UTType(filenameExtension: url.pathExtension)?.identifier ?? "unknown"

                var recoveredData: Data?
                var methodUsed = ""

                // 恢复策略一：若前 4 字节为 PNG 被破坏（全 0），还原为 PNG magic
                if originalData.prefix(4) == Data(repeating: 0x00, count: 4),
                   url.pathExtension.lowercased() == "png" {
                    let fixedHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
                    recoveredData = Data(fixedHeader) + originalData.dropFirst(4)
                    methodUsed = "Repaired PNG header"
                }
                // 恢复策略二：若 ZIP magic 被破坏（前两字节为 0）
                else if originalData.prefix(2) == Data(repeating: 0x00, count: 2),
                        url.pathExtension.lowercased() == "zip" {
                    let fixedHeader: [UInt8] = [0x50, 0x4B]
                    recoveredData = Data(fixedHeader) + originalData.dropFirst(2)
                    methodUsed = "Repaired ZIP header"
                }
                // 恢复策略三：若 JPEG/JPG 头部被清零
                else if originalData.prefix(3) == Data(repeating: 0x00, count: 3),
                        ["jpg", "jpeg"].contains(url.pathExtension.lowercased()) {
                    let fixedHeader: [UInt8] = [0xFF, 0xD8, 0xFF]
                    recoveredData = Data(fixedHeader) + originalData.dropFirst(3)
                    methodUsed = "Repaired JPEG header"
                }
                // 恢复策略四：若 PDF 头部被清零
                else if originalData.prefix(4) == Data(repeating: 0x00, count: 4),
                        url.pathExtension.lowercased() == "pdf" {
                    let fixedHeader: [UInt8] = [0x25, 0x50, 0x44, 0x46]   // %PDF
                    recoveredData = Data(fixedHeader) + originalData.dropFirst(4)
                    methodUsed = "Repaired PDF header"
                }
                // 恢复策略三：若头部疑似被按位取反（对 Header Flip 进行反转）
                else if !originalData.isEmpty {
                    // 尝试把前 headerSize 字节按位取反
                    let flippedPrefix = Data(originalData.prefix(headerSize).map { ~$0 })
                    let candidate = flippedPrefix + originalData.dropFirst(headerSize)
                    if headerMatches(candidate.prefix(4), ext: url.pathExtension) {
                        recoveredData = candidate
                        methodUsed = "Recovered by bitwise unflip"
                    }
                }
                // fallback：若前 256 字节全为 0，填充 0xFF 头部
                else if originalData.prefix(headerSize).allSatisfy({ $0 == 0 }) {
                    let fixedPrefix = Data(repeating: 0xFF, count: headerSize)
                    recoveredData = fixedPrefix + originalData.dropFirst(headerSize)
                    methodUsed = "Fallback recovery by header patch"
                }

                if recoveredData == nil {
                    // 到此说明未命中任何修复规则；若文件头看似正常，则认定“文件未损坏”
                    if headerMatches(originalData.prefix(8), ext: url.pathExtension) || preType != "unknown" {
                        DispatchQueue.main.async {
                            corruptedFiles.append(
                                (language == .chinese ? "ℹ️ 文件未损坏: " : "ℹ️ File is not corrupted: ")
                                + url.lastPathComponent
                            )
                            appendLog(.info, "ℹ️ File not corrupted: \(url.path)")
                        }
                        return
                    } else {
                        // 仍无法判断，保留旧的报错提示
                        throw NSError(domain: "BitTwister", code: 2, userInfo: [
                            NSLocalizedDescriptionKey: language == .chinese
                                ? "暂无法识别文件类型或修复策略"
                                : "Unknown corruption pattern or unsupported recovery strategy"
                        ])
                    }
                }

                // 此处 recoveredData 一定有值；若意外为 nil，则抛出内部错误
                guard let data = recoveredData else {
                    throw NSError(domain: "BitTwister", code: 99, userInfo: [
                        NSLocalizedDescriptionKey: "Internal error: recoveredData is nil"
                    ])
                }
                let outputURL: URL = {
                    if replaceCorrupted {
                        return url                                           // 覆盖原文件
                    } else if let dest = recoveryDestinationURL {
                        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
                        return dest.appendingPathComponent(url.lastPathComponent)
                    } else {
                        return url.deletingLastPathComponent()
                            .appendingPathComponent("recovered_" + url.lastPathComponent)
                    }
                }()
                try data.write(to: outputURL)

                // 恢复后验证 MIME 类型是否恢复
                let postType = UTType(filenameExtension: outputURL.pathExtension)?.identifier ?? "unknown"

                guard preType == postType, postType != "unknown" else {
                    throw NSError(domain: "BitTwister", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: language == .chinese
                            ? "修复失败，类型不匹配"
                            : "Recovery failed: file type mismatch"
                    ])
                }

                DispatchQueue.main.async {
                    corruptedFiles.append((language == .chinese ? "✅ 修复成功: " : "✅ Recovered: ") + outputURL.lastPathComponent + " (\(methodUsed))")
                    appendLog(.success, "✅ Recovered with \(methodUsed): \(outputURL.path)")
                }

            } catch {
                DispatchQueue.main.async {
                    corruptedFiles.append((language == .chinese ? "❌ 修复失败: " : "❌ Failed: ") + url.lastPathComponent)
                    appendLog(.error, "❌ Failed to recover \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
    }
}

/// 圆角淡色背景的顶部标签按钮样式
struct TopTabButtonStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                selected
                ? Color.accentColor.opacity(configuration.isPressed ? 0.55 : 0.25)
                : Color.clear
            )
            .cornerRadius(8)
    }
}

struct SettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @Binding var destinationURL: URL?
    @Binding var keepOriginal: Bool
    @Binding var language: Language
    @Binding var corruptionMethod: CorruptionMethod
    @Binding var themeOption: ThemeOption
    @Binding var recoveryDestinationURL: URL?
    @Binding var replaceCorrupted: Bool
    let isRecoveryMode: Bool

    // Tab bar state & metadata
    @State private var selectedTab: Int = 0
    private var tabInfo: [(String, String)] {
        [
            (loc("常规", "General", language), "gearshape"),
            (loc("高级", "Advanced", language), "slider.horizontal.3"),
            (loc("关于", "About", language), "info.circle")
        ]
    }

    /// 顶部标签栏
    private var topTabBar: some View {
        HStack(spacing: 12) {
            ForEach(0..<tabInfo.count, id: \.self) { idx in
                let (title, icon) = tabInfo[idx]
                Button(action: { selectedTab = idx }) {
                    VStack(spacing: 2) {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                        Text(title).font(.caption2)
                    }
                    .foregroundColor(selectedTab == idx ? .accentColor : .primary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TopTabButtonStyle(selected: selectedTab == idx))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Tab Contents (extracted)

    @ViewBuilder
    private var generalTab: some View {
        ScrollView {
            Form {
                Section(header: Text(loc("损坏模式", "Corruption Mode", language)).font(.headline).bold()) {
                    Toggle(loc("保留原文件", "Keep Original", language), isOn: $keepOriginal)
                    HStack {
                        Text(loc("保存路径", "Save Path", language))
                        Spacer()
                        Button(loc("选择...", "Choose…", language)) {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.canCreateDirectories = true
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let u = panel.url {
                                destinationURL = u
                            }
                        }
                    }
                    Text(destinationURL?.path ?? loc("未选择路径", "None", language))
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Section(header: Text(loc("恢复模式", "Recovery Mode", language)).font(.headline).bold()) {
                    Toggle(
                        loc("修复后替换原文件", "Replace damaged file after recovery", language),
                        isOn: $replaceCorrupted
                    )
                    HStack {
                        Text(loc("保存路径", "Save Path", language))
                        Spacer()
                        Button(loc("选择...", "Choose…", language)) {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.canCreateDirectories = true
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let u = panel.url {
                                recoveryDestinationURL = u
                            }
                        }
                    }
                    Text(recoveryDestinationURL?.path ?? loc("未选择路径", "None", language))
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Section(header: Text(loc("语言", "Language", language)).font(.headline).bold()) {
                    Picker("", selection: $language) {
                        ForEach(Language.allCases, id: \.self) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                Section(header: Text(loc("主题", "Theme", language)).font(.headline).bold()) {
                    Picker("", selection: $themeOption) {
                        ForEach(ThemeOption.allCases, id: \.self) { opt in
                            Text(language == .chinese ? opt.zh : opt.rawValue)
                                .tag(opt)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var advancedTab: some View {
        Form {
            Section(header: Text(loc("损坏方式", "Corruption Method", language)).font(.headline).bold()) {
                Picker("", selection: $corruptionMethod) {
                    ForEach(Array(CorruptionMethod.allCases), id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(RadioGroupPickerStyle())
            }

            Section(header: Text(loc("日志", "Logs", language)).font(.headline).bold()) {
                Stepper(
                    loc("日志上限: \(logLimit)", "Log limit: \(logLimit)", language),
                    value: $logLimit,
                    in: 10...2000,
                    step: 10
                )

                VStack(alignment: .leading) {
                    Text(loc("记录类型", "Log Types", language))
                    ForEach(Array(LogKind.allCases), id: \.self) { kind in
                        Toggle(
                            loc(kind.zh, kind.rawValue, language),
                            isOn: Binding<Bool>(
                                get: { enabledKinds.contains(kind) },
                                set: { isOn in
                                    var newSet = enabledKinds
                                    if isOn { newSet.insert(kind) }
                                    else    { newSet.remove(kind) }
                                    let newStr = newSet.map(\.rawValue).joined(separator: ",")
                                    if isRecoveryMode {
                                        enabledLogKindsRecovery = newStr
                                    } else {
                                        enabledLogKindsCorrupt = newStr
                                    }
                                }
                            )
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var aboutTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc("版本: 1.1.0", "Version: 1.1.0", language))
                Text(loc("作者: dazi2011", "Author: dazi2011", language))
                Link("GitHub: BitTwister",
                     destination: URL(string: "https://github.com/dazi2011/BitTwister")!)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // Storage for log settings
    @AppStorage("logLimit") private var logLimit: Int = 500
    @AppStorage("enabledLogKindsRecovery") private var enabledLogKindsRecovery: String = "Info,Warning,Error,Debug,Success"
    @AppStorage("enabledLogKindsCorrupt") private var enabledLogKindsCorrupt: String = "Info,Warning,Error,Debug,Success"

    private var enabledKindsRaw: String {
        get { isRecoveryMode ? enabledLogKindsRecovery : enabledLogKindsCorrupt }
        set {
            if isRecoveryMode {
                enabledLogKindsRecovery = newValue
            } else {
                enabledLogKindsCorrupt = newValue
            }
        }
    }

    private var enabledKinds: Set<LogKind> {
        get { Set(enabledKindsRaw.split(separator: ",").compactMap { LogKind(rawValue: String($0)) }) }
        set { enabledKindsRaw = newValue.map(\.rawValue).joined(separator: ",") }
    }

    var body: some View {
        VStack(spacing: 0) {
            topTabBar
            Divider()

            // ── Tab content ───────────────────────────────
            let content: AnyView = {
                switch selectedTab {
                case 0:  return AnyView(generalTab)      // 常规
                case 1:  return AnyView(advancedTab)     // 高级
                default: return AnyView(aboutTab)        // 关于
                }
            }()
            content
                .frame(maxHeight: .infinity)

            Divider()

            // ── Bottom buttons ────────────────────────────
            HStack {
                Spacer()
                Button(language == .chinese ? "应用" : "Apply") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)

                Button(language == .chinese ? "关闭" : "Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 540, height: 500)
        .onExitCommand { presentationMode.wrappedValue.dismiss() }
    }
}

struct LogView: View {
    @Environment(\.presentationMode) private var presentationMode
    var language: Language
    var logs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(language == .chinese ? "运行日志" : "Execution Logs")
                .font(.title2)
            Divider()
            ScrollView {
                ForEach(logs.indices, id: \.self) { idx in
                    Text(logs[idx])
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 1)
                }
            }
            Divider()
            HStack {
                Spacer()
                Button(language == .chinese ? "关闭" : "Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 520, height: 380)
        .onExitCommand { presentationMode.wrappedValue.dismiss() }
    }
}


extension ContentView {
    // MARK: - Top Tab Bar extracted view
    private var topTabBar: some View {
        HStack(spacing: 12) {
            ForEach(0..<tabInfo.count, id: \.self) { idx in
                let (title, icon) = tabInfo[idx]
                Button(action: { selectedTab = idx }) {
                    VStack(spacing: 2) {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                        Text(title).font(.caption2)
                    }
                    .foregroundColor(selectedTab == idx ? .accentColor : .primary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TopTabButtonStyle(selected: selectedTab == idx))
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

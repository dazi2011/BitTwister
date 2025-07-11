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
    @State private var corruptedFiles: [String] = []
    @State private var isHovering = false
    @State private var showAlert = false
    @State private var pendingURLs: [URL] = []
    @State private var showFileImporter: Bool = false

    @AppStorage("keepOriginal") private var keepOriginal: Bool = true
    @AppStorage("language")     private var languageRaw: String = Language.chinese.rawValue
    @AppStorage("corruption")   private var corruptionRaw: String = CorruptionMethod.headerFlip.rawValue
    @AppStorage("destPath")     private var destinationPath: String = ""
    @AppStorage("logLimit") private var logLimit: Int = 500        // max lines kept
    @AppStorage("logs")      private var logsRaw: String = ""      // lines joined by \n
    @AppStorage("theme") private var themeRaw: String = ThemeOption.system.rawValue

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

    var body: some View {
        Group {
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
                    handleDrop(providers: providers)
                    return true
                }

                if let lastPath = corruptedFiles.last {
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
                    handleDrop(providers: providers)
                    return true
                }

                if let lastPath = corruptedFiles.last {
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
                    set: { newVal in
                        themeRaw = newVal.rawValue        // mutate @AppStorage, avoids `self` immutability
                    }
                )
            )
        }
        .sheet(isPresented: $showLogs) {
            LogView(language: language, logs: logs)
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
@AppStorage("enabledLogKinds") private var enabledKindsRaw: String = "Info,Warning,Error,Debug,Success"
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

    private func corruptFile(at url: URL) {
        let headerSize = 256
        do {
            let fileData = try Data(contentsOf: url)
            let prefix = fileData.prefix(headerSize)
            let suffix = fileData.dropFirst(headerSize)
            let corruptedPrefix: Data
            switch corruptionMethod {
            case .headerFlip:
                corruptedPrefix = Data(prefix.map { ~$0 })
            case .randomBytes:
                corruptedPrefix = Data((0..<prefix.count).map { _ in UInt8.random(in: 0...255) })
            case .zeroFill:
                corruptedPrefix = Data(repeating: 0, count: prefix.count)
            case .reverseBytes:
                corruptedPrefix = Data(prefix.reversed())
            case .bitShiftLeft:
                corruptedPrefix = Data(prefix.map { $0 << 1 })
            }
            var corruptedData = Data()
            corruptedData.append(corruptedPrefix)
            corruptedData.append(suffix)
            let base = keepOriginal ? (destinationURL ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")) : url.deletingLastPathComponent()
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
            let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey]
            )!
            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(
                    forKeys: [.isRegularFileKey]
                )
                if values.isRegularFile == true {
                    corruptFile(at: fileURL)
                }
            }
        } catch {
            print("❌ 处理文件夹失败: \(error.localizedDescription)")
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
    @Binding var themeOption: ThemeOption      // ← 新增

    // Storage for log settings
    @AppStorage("logLimit") private var logLimit: Int = 500
    @AppStorage("enabledLogKinds") private var enabledKindsRaw: String = "Info,Warning,Error,Debug,Success"
    private var enabledKinds: Set<LogKind> {
        get { Set(enabledKindsRaw.split(separator: ",").compactMap { LogKind(rawValue: String($0)) }) }
        set { enabledKindsRaw = newValue.map(\.rawValue).joined(separator: ",") }
    }

    @State private var selectedTab: Int = 0      // 0‑General 1‑Advanced 2‑About

    var body: some View {
        VStack(spacing: 0) {
            // ── 顶部标签栏 ───────────────────────────────
            HStack(spacing: 12) {
                ForEach(0..<3) { idx in
                    let title = [
                        loc("常规","General",language),
                        loc("高级","Advanced",language),
                        loc("关于","About",language)
                    ][idx]
                    let icon  = ["gearshape",
                                 "slider.horizontal.3",
                                 "info.circle"][idx]

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

            Divider()

            // ── Tab content ───────────────────────────────
            Group {
                switch selectedTab {
                case 0:                      // GENERAL
                    ScrollView {
                        Form {
                            Section {
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
                            Section(loc("语言", "Language", language)) {
                                Picker("", selection: $language) {
                                    ForEach(Language.allCases, id: \.self) { lang in
                                        Text(lang.rawValue).tag(lang)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            Section(loc("主题", "Theme", language)) {
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

                case 1:                      // ADVANCED
                    Form {
                        Section(loc("损坏方式", "Corruption Method", language)) {
                            Picker("", selection: $corruptionMethod) {
                                ForEach(Array(CorruptionMethod.allCases), id: \.self) { method in
                                    Text(method.rawValue).tag(method)
                                }
                            }
                            .pickerStyle(RadioGroupPickerStyle())
                        }

                        Section(loc("日志", "Logs", language)) {
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
                                                enabledKindsRaw = newSet.map(\.rawValue).joined(separator: ",")
                                            }
                                        )
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)

                default:                     // ABOUT
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(loc("版本: 1.0.0", "Version: 1.0.0", language))
                            Text(loc("作者: 达子", "Author: Dazi", language))
                            Link("GitHub: BitTwister",
                                 destination: URL(string: "https://github.com/dazi2011/BitTwister")!)
                        }
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
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

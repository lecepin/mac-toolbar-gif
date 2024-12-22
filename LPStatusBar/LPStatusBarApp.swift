//
//  LPStatusBarApp.swift
//  LPStatusBar
//
//  Created by 王乐平 on 2024/12/22.
//

import SwiftUI
import AppKit
import ServiceManagement  // 添加这行
import WebKit  // 添加在文件顶部其他 import 语句旁边

// MARK: - 数据模型
struct GifItem: Codable, Identifiable {
    let id: UUID
    var path: String
    var isEnabled: Bool
    var type: PathType
    
    enum PathType: String, Codable {
        case url
        case file
    }
    
    init(id: UUID = UUID(), path: String, type: PathType, isEnabled: Bool = true) {
        self.id = id
        self.path = path
        self.type = type
        self.isEnabled = isEnabled
    }
}

// MARK: - ViewModel
class StatusBarViewModel: ObservableObject {
    @Published var items: [GifItem] = []
    @Published var launchAtLogin: Bool = false {
        didSet {
            do {
                if launchAtLogin {
                    print("📍 正在设置开机启动...")
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                    try SMAppService.mainApp.register()
                    print("✅ 开机启动设置成功")
                } else {
                    print("📍 正在取消开机启动...")
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                        print("✅ 已取消开机启动")
                    }
                }
            } catch {
                print("❌ 开机启动设置失败: \(error)")
                print("❌ 错误详情: \(error.localizedDescription)")
                // 恢复状态
                DispatchQueue.main.async {
                    self.launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
        }
    }
    private let defaults = UserDefaults.standard
    
    init() {
        // 检查是否已注册开机启动
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        print("📍 开机启动状态检查: \(self.launchAtLogin ? "已启用" : "未启用")")
        loadItems()
    }
    
    func addItem(path: String, type: GifItem.PathType) {
        let newItem = GifItem(path: path, type: type)
        items.append(newItem)
    }
    
    func toggleItem(_ id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isEnabled.toggle()
        }
    }
    
    func removeItem(_ id: UUID) {
        items.removeAll { $0.id == id }
    }
    
    func saveItems() {
        do {
            // 使用PropertyListEncoder而不是JSONEncoder
            let encoder = PropertyListEncoder()
            let data = try encoder.encode(items)
            defaults.set(data, forKey: "GifItems")
            print("✅ 保存配置成功，项目数: \(items.count)")  // 添加日志
        } catch {
            print("❌ 保存配置失败: \(error)")  // 添加日志
        }
    }
    
    private func loadItems() {
        do {
            if let data = defaults.data(forKey: "GifItems") {
                // 使用PropertyListDecoder而不是JSONDecoder
                let decoder = PropertyListDecoder()
                items = try decoder.decode([GifItem].self, from: data)
                print("✅ 加载配置成功，项目数: \(items.count)")  // 添加日志
            }
        } catch {
            print("❌ 加载配置失败: \(error)")  // 添加日志
            items = []  // 如果加载失败，使用空数组
        }
    }
    
    func isValidURL(_ urlString: String) -> Bool {
        let urlRegEx = "^(https?://)?(([\\w!~*'().&=+$%-]+: )?[\\w!~*'().&=+$%-]+@)?(([0-9]{1,3}\\.){3}[0-9]{1,3}|([\\w!~*'()-]+\\.)*[\\w!~*'()-]+\\.[a-zA-Z]{2,6})(:[0-9]{1,5})?([/?\\w!~*'().;?:@&=+$,%#-]+)?$"
        let urlTest = NSPredicate(format:"SELF MATCHES %@", urlRegEx)
        return urlTest.evaluate(with: urlString)
    }
    
    func printCurrentConfig() {
        if let data = defaults.data(forKey: "GifItems"),
           let items = try? PropertyListDecoder().decode([GifItem].self, from: data) {
            print("\n当前配置内容:")
            print("------------------------")
            for (index, item) in items.enumerated() {
                print("项目 \(index + 1):")
                print("  路径: \(item.path)")
                print("  类型: \(item.type)")
                print("  启用: \(item.isEnabled)")
                print("------------------------")
            }
        } else {
            print("没有找到保存的配置")
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    @ObservedObject var viewModel: StatusBarViewModel
    @State private var newUrl: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("在 Bar 上设置 GIF")
                    .font(.headline)
                Spacer()
                Button(action: {
                    AboutWindowController.shared.showWindow()
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom)
            
            HStack {
                TextField("输入GIF URL", text: $newUrl)
                Button("添加URL") {
                    if !newUrl.isEmpty {
                        if viewModel.isValidURL(newUrl) {
                            viewModel.addItem(path: newUrl, type: .url)
                            newUrl = ""
                        } else {
                            showToast("无效的URL地址：\(newUrl)")
                        }
                    }
                }
                Button("添加文件") {
                    selectGifFile()
                }
            }
            
            List {
                ForEach(viewModel.items) { item in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { item.isEnabled },
                            set: { _ in viewModel.toggleItem(item.id) }
                        ))
                        Image(systemName: item.type == .url ? "link" : "doc")
                            .foregroundColor(.secondary)
                        Text(item.path)
                        Spacer()
                        Button(action: { viewModel.removeItem(item.id) }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .frame(height: 120)
            
            Button("保存配置") {
                viewModel.saveItems()
                viewModel.printCurrentConfig()
                NotificationCenter.default.post(name: .refreshStatusBarItems, object: nil)
            }
            .frame(maxWidth: .infinity)
            
            Toggle("开机启动", isOn: $viewModel.launchAtLogin)
                .padding(.top, 8)
        }
        .padding()
    }
    
    private func selectGifFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            print("📍 选择文件: \(url.path)")
            viewModel.addItem(path: url.path, type: .file)
            viewModel.saveItems()
        }
    }
}

// 添加 WindowAccessor 视图
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Notification Names
extension Notification.Name {
    static let refreshStatusBarItems = Notification.Name("refreshStatusBarItems")
}

// MARK: - App & AppDelegate
@main
struct LPStatusBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: appDelegate.viewModel)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 200)
    }
}

// 自定义Toast视图
class ToastWindow: NSWindow {
    init() {
        // 初始化时使用最小尺寸
        let windowRect = NSRect(x: 0, y: 0, width: 100, height: 40)
        super.init(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // 设置窗属性
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        ignoresMouseEvents = true
        
        // 创建主容器视图
        let containerView = NSView(frame: windowRect)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.cgColor
        containerView.layer?.cornerRadius = 8
        
        // 创建文本标签
        let label = NSTextField(wrappingLabelWithString: "")
        label.frame = NSRect(x: 16, y: 0, width: 0, height: 0)  // 初始大小为0
        label.textColor = .white
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.alignment = .center
        label.backgroundColor = .clear
        label.isEditable = false
        label.isBordered = false
        label.cell?.wraps = true
        label.cell?.truncatesLastVisibleLine = false
        label.maximumNumberOfLines = 0  // 允许多行
        label.lineBreakMode = .byWordWrapping  // 按词换行
        
        // 组装视图
        containerView.addSubview(label)
        contentView = containerView
    }
    
    func show(_ message: String) {
        guard let containerView = contentView,
              let label = containerView.subviews.first as? NSTextField else { return }
        
        // 设置文字
        label.stringValue = message
        
        // 计算合适的文本大小
        let padding: CGFloat = 16
        let maxWidth: CGFloat = 400  // 最大宽度
        let minWidth: CGFloat = 100  // 最小宽度
        
        // 先计算文本的理想大小
        let constrainedSize = NSSize(width: maxWidth - padding * 2, height: CGFloat.greatestFiniteMagnitude)
        let idealSize = label.cell?.cellSize(forBounds: NSRect(origin: .zero, size: constrainedSize)) ?? .zero
        
        // 计算实际窗口尺寸
        let actualWidth = min(maxWidth, max(minWidth, idealSize.width + padding * 2))
        let actualHeight = idealSize.height + padding * 2
        
        // 更新标签大小和位置
        label.frame = NSRect(
            x: padding,
            y: (actualHeight - idealSize.height) / 2,
            width: actualWidth - padding * 2,
            height: idealSize.height
        )
        
        // 更新容器和窗口大小
        let newFrame = NSRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: actualWidth,
            height: actualHeight
        )
        containerView.frame = NSRect(origin: .zero, size: newFrame.size)
        setFrame(newFrame, display: true)
        
        // 计算屏幕位置
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - frame.width/2
            let y = screenRect.maxY - frame.height - 60
            setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // 显示动画
        orderFront(nil)
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            animator().alphaValue = 1
        }
        
        // 3秒后消失
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self?.animator().alphaValue = 0
            } completionHandler: {
                self?.orderOut(nil)
            }
        }
    }
}

// // 修改全局Toast函数

let toastWindow = ToastWindow()

func showToast(_ message: String) {
    print("📢 Toast: \(message)")
    DispatchQueue.main.async {
        toastWindow.show(message)
    }
}

// 在 showToast 函数后添加 AppDelegate 类实现
class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = StatusBarViewModel()
    private var statusItems: [UUID: NSStatusItem] = [:]
    private var animationTimers: [UUID: Timer] = [:]
    private var gifFrames: [UUID: [NSImage]] = [:]
    private var currentFrames: [UUID: Int] = [:]
    
    private func showError(_ message: String) {
        print("❌ 错误: \(message)")
        // 避免在错误处理中再次触发错误
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            if let window = NSApp.windows.first {
                alert.beginSheetModal(for: window) { _ in }
            } else {
                alert.runModal()
            }
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 配置窗口样式
        if let window = NSApplication.shared.windows.first {
            // 只保留关闭和最小化按钮，移除最大化按钮
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            
            // 禁用全屏按钮
            window.collectionBehavior = []
        }
        
        // 清空菜单栏
        NSApp.mainMenu = NSMenu()
        
        // 添加观察者
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshStatusBarItems),
            name: .refreshStatusBarItems,
            object: nil
        )
        
        refreshStatusBarItems()
        
        // 设置菜单栏
        let mainMenu = NSMenu()
        
        // 应用单
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "关于", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc private func refreshStatusBarItems() {
        // 清理现有的状态栏项
        clearAllStatusItems()
        
        // 创建新的状态栏项
        for item in viewModel.items where item.isEnabled {
            createStatusItem(for: item)
        }
    }
    
    private func createStatusItem(for item: GifItem) {
        print("开始创建状态栏项: \(item.path), 类型: \(item.type)")
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItems[item.id] = statusItem
        
        let url: URL
        switch item.type {
        case .url:
            guard let networkUrl = URL(string: item.path) else {
                showError("无效的URL地址：\(item.path)")
                return
            }
            url = networkUrl
            
        case .file:
            let fileUrl = URL(fileURLWithPath: item.path)
            guard FileManager.default.fileExists(atPath: fileUrl.path) else {
                showError("文件不存在：\(item.path)")
                return
            }
            url = fileUrl
        }
        
        loadGIFFrames(from: url) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let frames):
                print("✅ GIF加载成功，帧数: \(frames.count)")
                self.gifFrames[item.id] = frames
                self.currentFrames[item.id] = 0
                
                if let firstFrame = frames.first {
                    self.statusItems[item.id]?.button?.image = firstFrame
                    print("✅ 已设置第一帧到状态栏")
                }
                self.startAnimation(for: item.id)
                
            case .failure(let error):
                print("❌ GIF加载失败: \(error)")
                let errorMessage = item.type == .url ? 
                    "URL加载失败：\(item.path)" :
                    "文件加载失败：\(item.path)"
                self.showError(errorMessage)
                self.removeStatusItem(for: item.id)
            }
        }
    }
    
    private func loadGIFFrames(from url: URL, completion: @escaping (Result<[NSImage], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let data: Data
                if url.isFileURL {
                    data = try Data(contentsOf: url)
                } else {
                    data = try Data(contentsOf: url)
                }
                
                DispatchQueue.main.async {
                    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                        completion(.failure(NSError(domain: "", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "无效的GIF数据"])))
                        return
                    }
                    
                    let frameCount = CGImageSourceGetCount(source)
                    print("📍 GIF帧数: \(frameCount)")
                    
                    var frames: [NSImage] = []
                    let maxHeight: CGFloat = 22  // 状态栏的最大高度
                    let maxWidth: CGFloat = 44   // 状态栏允许的最大宽度
                    
                    let options: [CFString: Any] = [
                        kCGImageSourceThumbnailMaxPixelSize: max(maxWidth, maxHeight),
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceCreateThumbnailFromImageAlways: true
                    ]
                    
                    for i in 0..<frameCount {
                        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, i, options as CFDictionary) {
                            // 计算保持宽高比的尺寸
                            let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
                            let aspectRatio = originalSize.width / originalSize.height
                            
                            var finalWidth: CGFloat
                            var finalHeight: CGFloat
                            
                            if aspectRatio > 1 {
                                // 宽图
                                finalWidth = min(maxWidth, originalSize.width)
                                finalHeight = finalWidth / aspectRatio
                            } else {
                                // 高图
                                finalHeight = min(maxHeight, originalSize.height)
                                finalWidth = finalHeight * aspectRatio
                            }
                            
                            let image = NSImage(cgImage: cgImage, size: NSSize(width: finalWidth, height: finalHeight))
                            frames.append(image)
                        }
                    }
                    
                    if frames.isEmpty {
                        completion(.failure(NSError(domain: "", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "No valid frames in GIF"])))
                    } else {
                        completion(.success(frames))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func startAnimation(for id: UUID) {
        animationTimers[id]?.invalidate()
        
        animationTimers[id] = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let frames = self.gifFrames[id],
                  !frames.isEmpty else { return }
            
            self.currentFrames[id] = ((self.currentFrames[id] ?? 0) + 1) % frames.count
            self.statusItems[id]?.button?.image = frames[self.currentFrames[id] ?? 0]
        }
    }
    
    private func removeStatusItem(for id: UUID) {
        animationTimers[id]?.invalidate()
        animationTimers[id] = nil
        
        if let item = statusItems[id] {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems[id] = nil
        gifFrames[id] = nil
        currentFrames[id] = nil
    }
    
    private func clearAllStatusItems() {
        for (id, _) in statusItems {
            removeStatusItem(for: id)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        clearAllStatusItems()
    }
    
    @objc func showAbout() {
        AboutWindowController.shared.showWindow()
    }
}

// 添加关于窗口控制器
class AboutWindowController: NSWindowController {
    static let shared = AboutWindowController()
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "关于"
        window.center()
        
        // 设置为模态窗口
        window.isMovableByWindowBackground = false
        window.level = .modalPanel
        
        super.init(window: window)
        
        // 创建主视图
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        
        // 应用图标
        let iconSize: CGFloat = 64
        let iconX = (400 - iconSize) / 2  // 居中计算
        let iconImageView = NSImageView(frame: NSRect(x: iconX, y: 120, width: iconSize, height: iconSize))
        if let appIcon = NSApp.applicationIconImage {
            iconImageView.image = appIcon
        }
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        
        // 版本信息
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionLabel = NSTextField(labelWithString: "版本 \(version) (\(build))")
        versionLabel.frame = NSRect(x: 0, y: 80, width: 400, height: 20)
        versionLabel.alignment = .center
        versionLabel.font = .systemFont(ofSize: 13)
        versionLabel.backgroundColor = .clear
        versionLabel.isEditable = false
        versionLabel.isBordered = false
        
        // GitHub链接
        let linkLabel = NSTextField(labelWithString: "项目地址")
        let linkText = NSTextField(labelWithString: "https://github.com/lecepin/mac-toolbar-gif")
        linkText.attributedStringValue = NSAttributedString(
            string: "https://github.com/lecepin/mac-toolbar-gif",
            attributes: [
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )

        // 设置标签样式
        for label in [linkLabel, linkText] {
            label.isEditable = false
            label.isBordered = false
            label.backgroundColor = .clear
            label.alignment = .center
        }

        // 计算居中位置
        let totalWidth = linkLabel.cell!.cellSize.width + 4 + linkText.cell!.cellSize.width
        let startX = (400 - totalWidth) / 2
        linkLabel.frame = NSRect(x: startX, y: 40, width: linkLabel.cell!.cellSize.width, height: 20)
        linkText.frame = NSRect(x: startX + linkLabel.frame.width + 4, y: 40, width: linkText.cell!.cellSize.width, height: 20)

        // 添加点击事件
        linkText.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(openGitHub)))
        linkText.isSelectable = false

        // 添加到视图
        contentView.addSubview(iconImageView)
        contentView.addSubview(versionLabel)
        contentView.addSubview(linkLabel)
        contentView.addSubview(linkText)
        window.contentView = contentView
        
        // 添加窗口关闭通知监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showWindow() {
        if let window = self.window {
            NSApp.runModal(for: window)
        }
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        NSApp.stopModal()
    }
    
    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/lecepin/mac-toolbar-gif") {
            NSWorkspace.shared.open(url)
        }
    }
}

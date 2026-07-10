import UIKit
import UniformTypeIdentifiers
import UserNotifications

final class ShareViewController: UIViewController {
    private static let appGroupIdentifier = "group.com.shoko.forms"
    private static let incomingFolderName = "ExternalImports"
    private static let openNotificationCategoryIdentifier = "SHOKO_EXTERNAL_IMPORT"
    private static let openNotificationActionIdentifier = "OPEN_SHOKO"
    private var didStartImport = false
    private var didAttemptAutomaticOpen = false
    private var pendingHostURL: URL?
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let guideImageView = UIImageView()
    private let actionButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureView()
        updateStatus("ファイルを準備しています...", actionTitle: nil)
    }

    private func configureView() {
        titleLabel.text = "Shoko Forms"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        guideImageView.image = Self.notificationOpenGuideImage()
        guideImageView.contentMode = .scaleAspectFit
        guideImageView.clipsToBounds = false
        guideImageView.backgroundColor = .clear
        guideImageView.isHidden = true
        guideImageView.accessibilityLabel = "通知をタップしてShoko Formsを開く案内"

        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = .systemBlue
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
        actionButton.configuration = configuration
        actionButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        actionButton.isHidden = true
        actionButton.addTarget(self, action: #selector(openHostAppButtonTapped), for: .touchUpInside)

        cancelButton.setTitle("キャンセル", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [titleLabel, statusLabel, guideImageView, actionButton, cancelButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            guideImageView.heightAnchor.constraint(equalTo: guideImageView.widthAnchor, multiplier: 975.0 / 1022.0),
            actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStartImport else { return }
        didStartImport = true
        persistSharedItems()
    }

    private func persistSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            finish()
            return
        }

        let providers = extensionItems
            .flatMap { $0.attachments ?? [] }
        let pdfProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) }
        let selectedProviders = pdfProviders.first.map { [$0] } ?? providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }

        guard !selectedProviders.isEmpty,
              let targetDirectory = makeTargetDirectory()
        else {
            finish()
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var copiedCount = 0

        for provider in selectedProviders {
            group.enter()
            if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
                copyPDF(from: provider, to: targetDirectory) { didCopy in
                    if didCopy {
                        lock.lock()
                        copiedCount += 1
                        lock.unlock()
                    }
                    group.leave()
                }
            } else {
                copyImage(from: provider, to: targetDirectory) { didCopy in
                    if didCopy {
                        lock.lock()
                        copiedCount += 1
                        lock.unlock()
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if copiedCount > 0 {
                self.prepareHostAppOpen(token: targetDirectory.lastPathComponent, copiedCount: copiedCount)
            } else {
                self.updateStatus("ファイルを読み込めませんでした。もう一度共有してください。", actionTitle: nil)
            }
        }
    }

    private func copyPDF(from provider: NSItemProvider, to targetDirectory: URL, completion: @escaping (Bool) -> Void) {
        let typeIdentifier = registeredTypeIdentifier(from: provider, conformingTo: .pdf) ?? UTType.pdf.identifier
        copyFileRepresentation(
            from: provider,
            typeIdentifier: typeIdentifier,
            to: targetDirectory,
            fallbackExtension: "pdf",
            completion: completion
        )
    }

    private func copyImage(from provider: NSItemProvider, to targetDirectory: URL, completion: @escaping (Bool) -> Void) {
        guard let typeIdentifier = registeredTypeIdentifier(from: provider, conformingTo: .image),
              let fileExtension = UTType(typeIdentifier)?.preferredFilenameExtension
        else {
            completion(false)
            return
        }

        copyFileRepresentation(
            from: provider,
            typeIdentifier: typeIdentifier,
            to: targetDirectory,
            fallbackExtension: fileExtension,
            completion: completion
        )
    }

    private func registeredTypeIdentifier(from provider: NSItemProvider, conformingTo targetType: UTType) -> String? {
        provider.registeredTypeIdentifiers.first { identifier in
            UTType(identifier)?.conforms(to: targetType) == true
        }
    }

    private func copyFileRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String,
        to targetDirectory: URL,
        fallbackExtension: String,
        completion: @escaping (Bool) -> Void
    ) {
        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] sourceURL, _ in
            guard let self, let sourceURL else {
                self?.copyInPlaceFileRepresentation(
                    from: provider,
                    typeIdentifier: typeIdentifier,
                    to: targetDirectory,
                    fallbackExtension: fallbackExtension,
                    completion: completion
                )
                return
            }
            completion(self.copyFile(at: sourceURL, provider: provider, to: targetDirectory, fallbackExtension: fallbackExtension))
        }
    }

    private func copyInPlaceFileRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String,
        to targetDirectory: URL,
        fallbackExtension: String,
        completion: @escaping (Bool) -> Void
    ) {
        provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] sourceURL, _, _ in
            guard let self, let sourceURL else {
                completion(false)
                return
            }
            completion(self.copyFile(at: sourceURL, provider: provider, to: targetDirectory, fallbackExtension: fallbackExtension))
        }
    }

    private func copyFile(at sourceURL: URL, provider: NSItemProvider, to targetDirectory: URL, fallbackExtension: String) -> Bool {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destination = targetDirectory.appendingPathComponent("\(UUID().uuidString)-\(fileName(for: provider, fallbackExtension: fallbackExtension))")
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return true
        } catch {
            return false
        }
    }

    private func makeTargetDirectory() -> URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) else {
            return nil
        }
        let directory = container
            .appendingPathComponent(Self.incomingFolderName, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            return nil
        }
    }

    private func fileName(for provider: NSItemProvider, fallbackExtension: String) -> String {
        let suggested = provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = suggested?.isEmpty == false ? suggested! : "shoko-import"
        let cleanBase = baseName
            .map { character -> Character in
                ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"].contains(String(character)) ? "-" : character
            }
        let name = String(cleanBase)
        if name.lowercased().hasSuffix(".\(fallbackExtension)") {
            return name
        }
        return "\(name).\(fallbackExtension)"
    }

    private func prepareHostAppOpen(token: String, copiedCount: Int) {
        var components = URLComponents()
        components.scheme = "shokoforms"
        components.host = "external-import"
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components.url else {
            updateStatus("Shoko を開くURLを作成できませんでした。", actionTitle: nil)
            return
        }
        pendingHostURL = url
        updateStatus("ファイル \(copiedCount) 件を準備しました。Shoko を開いて取り込み先の表單を選択してください。", actionTitle: "Shoko を開く")
        automaticallyOpenHostAppIfNeeded()
    }

    @objc private func openHostAppButtonTapped() {
        openHostApp()
    }

    private func automaticallyOpenHostAppIfNeeded() {
        guard !didAttemptAutomaticOpen else { return }
        didAttemptAutomaticOpen = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.openHostApp()
        }
    }

    private func openHostApp() {
        guard let url = pendingHostURL else {
            updateStatus("Shoko を開くURLがありません。もう一度共有してください。", actionTitle: nil)
            return
        }
        actionButton.isEnabled = false
        updateStatus("Shoko を開いています...", actionTitle: "Shoko を開く")
        extensionContext?.open(url) { [weak self] didOpen in
            DispatchQueue.main.async {
                guard let self else { return }
                if didOpen {
                    self.finish()
                } else {
                    let didAttemptFallback = self.openHostAppThroughResponderChain(url)
                    self.scheduleOpenReminderNotification()
                    self.showOpenFailureAfterFallbackDelay(didAttemptFallback: didAttemptFallback)
                }
            }
        }
    }

    private func showOpenFailureAfterFallbackDelay(didAttemptFallback: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.view.window != nil else { return }
            self.actionButton.isEnabled = true
            let message = didAttemptFallback
                ? "Shoko を自動で開けない場合は、この画面を閉じて Shoko を開いてください。保存済みファイルは自動で導入画面に表示されます。"
                : "Shoko を開けませんでした。通知またはホーム画面から Shoko を開くと、保存済みファイルの導入画面が表示されます。"
            self.updateStatus(message, actionTitle: "もう一度開く", showsGuideImage: true)
        }
    }

    private func openHostAppThroughResponderChain(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let currentResponder = responder {
            if currentResponder.responds(to: selector) {
                currentResponder.perform(selector, with: url)
                return true
            }
            responder = currentResponder.next
        }
        return false
    }

    private func scheduleOpenReminderNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { isGranted, _ in
            guard isGranted else { return }
            Self.registerOpenReminderNotificationCategory(on: center)
            let content = UNMutableNotificationContent()
            content.title = "Shoko Forms"
            content.body = "保存済みファイルがあります。通知をタップ、または「Shoko を開く」を押して導入を完了してください。"
            content.sound = .default
            content.categoryIdentifier = Self.openNotificationCategoryIdentifier
            if let imageURL = Self.notificationOpenGuideURL(),
               let attachment = try? UNNotificationAttachment(identifier: "notification-open-guide", url: imageURL) {
                content.attachments = [attachment]
            }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "shoko.external-import.\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    private static func registerOpenReminderNotificationCategory(on center: UNUserNotificationCenter) {
        let openAction = UNNotificationAction(
            identifier: openNotificationActionIdentifier,
            title: "Shoko を開く",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: openNotificationCategoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    @objc private func cancelButtonTapped() {
        finish()
    }

    private func updateStatus(_ text: String, actionTitle: String?, showsGuideImage: Bool = false) {
        statusLabel.text = text
        if guideImageView.image == nil {
            guideImageView.image = Self.notificationOpenGuideImage()
        }
        guideImageView.isHidden = !showsGuideImage || guideImageView.image == nil
        if let actionTitle {
            actionButton.setTitle(actionTitle, for: .normal)
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private static func notificationOpenGuideURL() -> URL? {
        Bundle(for: ShareViewController.self).url(forResource: "NotificationOpenGuide", withExtension: "jpg")
    }

    private static func notificationOpenGuideImage() -> UIImage? {
        guard let url = notificationOpenGuideURL() else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

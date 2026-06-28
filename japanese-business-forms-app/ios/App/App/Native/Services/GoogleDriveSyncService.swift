import Combine
import Foundation
import GoogleSignIn
import UIKit

enum GoogleDriveSyncError: Error {
    case missingGoogleConfiguration
    case presentingViewControllerUnavailable
    case authorizationCancelled
    case authorizationFailed(String)
    case tokenExpired
    case cloudBackupNotFound
    case invalidDriveResponse
    case networkUnavailable
    case driveAPIUnavailable(projectID: String?)
    case server(statusCode: Int, message: String)
}

struct GoogleDriveCloudBackupFile: Identifiable {
    let fileId: String
    let name: String
    let modifiedTime: String?
    let size: Int64?

    var id: String { fileId }
}

@MainActor
final class GoogleDriveSyncService: ObservableObject {
    static let driveFileScope = "https://www.googleapis.com/auth/drive.file"

    @Published private(set) var isConfigured = false
    @Published private(set) var isSignedIn = false
    @Published private(set) var accountEmail = ""

    init() {
        isConfigured = Self.configureSignInIfPossible()
        updatePublishedUser(GIDSignIn.sharedInstance.currentUser)
    }

    func restorePreviousSignIn() async {
        guard isConfigured, GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            updatePublishedUser(GIDSignIn.sharedInstance.currentUser)
            return
        }

        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            updatePublishedUser(user)
        } catch {
            updatePublishedUser(nil)
        }
    }

    func signIn() async throws {
        let presentingViewController = try currentPresentingViewController()
        _ = try await freshAccessToken(presenting: presentingViewController)
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        updatePublishedUser(nil)
    }

    func uploadAppBackup(data: Data, existingFileID: String?) async throws -> GoogleDriveCloudBackupFile {
        let presentingViewController = try currentPresentingViewController()
        let accessToken = try await freshAccessToken(presenting: presentingViewController)
        let client = GoogleDriveAPIClient(accessToken: accessToken)
        return try await client.uploadCloudBackup(data: data, existingFileID: existingFileID)
    }

    func downloadAppBackup(existingFileID: String?) async throws -> (file: GoogleDriveCloudBackupFile, data: Data) {
        let presentingViewController = try currentPresentingViewController()
        let accessToken = try await freshAccessToken(presenting: presentingViewController)
        let client = GoogleDriveAPIClient(accessToken: accessToken)
        return try await client.downloadCloudBackup(existingFileID: existingFileID)
    }

    func listAppBackups() async throws -> [GoogleDriveCloudBackupFile] {
        let presentingViewController = try currentPresentingViewController()
        let accessToken = try await freshAccessToken(presenting: presentingViewController)
        let client = GoogleDriveAPIClient(accessToken: accessToken)
        return try await client.listCloudBackups()
    }

    func downloadAppBackup(fileID: String) async throws -> (file: GoogleDriveCloudBackupFile, data: Data) {
        let presentingViewController = try currentPresentingViewController()
        let accessToken = try await freshAccessToken(presenting: presentingViewController)
        let client = GoogleDriveAPIClient(accessToken: accessToken)
        return try await client.downloadCloudBackup(fileID: fileID)
    }

    func uploadDocumentFile(
        data: Data,
        fileName: String,
        mimeType: String,
        documentType: DocumentType,
        existingFileID: String?
    ) async throws -> GoogleDriveCloudBackupFile {
        let presentingViewController = try currentPresentingViewController()
        let accessToken = try await freshAccessToken(presenting: presentingViewController)
        let client = GoogleDriveAPIClient(accessToken: accessToken)
        return try await client.uploadDocumentFile(
            data: data,
            fileName: fileName,
            mimeType: mimeType,
            folderName: documentType.googleDriveFolderName,
            existingFileID: existingFileID
        )
    }

    private func freshAccessToken(presenting presentingViewController: UIViewController) async throws -> String {
        guard Self.configureSignInIfPossible() else {
            isConfigured = false
            throw GoogleDriveSyncError.missingGoogleConfiguration
        }
        isConfigured = true

        do {
            let scopedUser: GIDGoogleUser
            if let currentUser = GIDSignIn.sharedInstance.currentUser {
                scopedUser = try await userWithDriveScope(currentUser, presenting: presentingViewController)
            } else {
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: presentingViewController,
                    hint: nil,
                    additionalScopes: [Self.driveFileScope]
                )
                scopedUser = result.user
            }

            let refreshedUser = try await scopedUser.refreshTokensIfNeeded()
            updatePublishedUser(refreshedUser)
            return refreshedUser.accessToken.tokenString
        } catch let error as GoogleDriveSyncError {
            throw error
        } catch {
            throw mapAuthorizationError(error)
        }
    }

    private func userWithDriveScope(_ user: GIDGoogleUser, presenting presentingViewController: UIViewController) async throws -> GIDGoogleUser {
        if user.grantedScopes?.contains(Self.driveFileScope) == true {
            return user
        }

        do {
            let result = try await user.addScopes([Self.driveFileScope], presenting: presentingViewController)
            return result.user
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn", nsError.code == -8 {
                return user
            }
            throw mapAuthorizationError(error)
        }
    }

    private func mapAuthorizationError(_ error: Error) -> GoogleDriveSyncError {
        let nsError = error as NSError
        if nsError.domain == "com.google.GIDSignIn", nsError.code == -5 {
            return .authorizationCancelled
        }
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return .authorizationCancelled
        }
        if nsError.domain == "com.google.GIDSignIn", nsError.code == -4 {
            return .tokenExpired
        }
        return .authorizationFailed(nsError.localizedDescription)
    }

    private func updatePublishedUser(_ user: GIDGoogleUser?) {
        isSignedIn = user != nil
        accountEmail = user?.profile?.email ?? ""
    }

    private static func configureSignInIfPossible() -> Bool {
        guard let clientID = validInfoPlistValue(for: "GIDClientID"),
              hasValidGoogleURLScheme() else {
            return false
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        return true
    }

    private static func validInfoPlistValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("REPLACE_WITH"), !trimmed.contains("$(") else {
            return nil
        }
        return trimmed
    }

    private static func hasValidGoogleURLScheme() -> Bool {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return false
        }
        return urlTypes.contains { entry in
            guard let schemes = entry["CFBundleURLSchemes"] as? [String] else { return false }
            return schemes.contains { scheme in
                let trimmed = scheme.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && !trimmed.contains("REPLACE_WITH") && !trimmed.contains("$(")
            }
        }
    }

    private func currentPresentingViewController() throws -> UIViewController {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let rootViewController = activeScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            throw GoogleDriveSyncError.presentingViewControllerUnavailable
        }
        return rootViewController.topMostViewController()
    }
}

private struct GoogleDriveAPIClient {
    private let accessToken: String
    private let session: URLSession
    private let decoder = JSONDecoder()

    private static let rootFolderName = "商業書類Backup"
    private static let legacyBackupFileName = "shoko-forms-cloud-backup.shokobackup"
    private static let backupMimeType = "application/vnd.shoko.forms.backup+json"
    private static let folderMimeType = "application/vnd.google-apps.folder"

    init(accessToken: String, session: URLSession = .shared) {
        self.accessToken = accessToken
        self.session = session
    }

    func uploadCloudBackup(data: Data, existingFileID: String?) async throws -> GoogleDriveCloudBackupFile {
        let rootFolder = try await findOrCreateFolder(named: Self.rootFolderName, parentID: nil)
        let monthFolder = try await findOrCreateFolder(named: Self.currentMonthFolderName(), parentID: rootFolder.id)
        let name = Self.backupFileName()
        let file = try await uploadOrUpdateFile(
            name: name,
            mimeType: Self.backupMimeType,
            data: data,
            parentID: monthFolder.id,
            existingFileID: nil
        )
        return file.cloudBackupFile
    }

    func downloadCloudBackup(existingFileID: String?) async throws -> (file: GoogleDriveCloudBackupFile, data: Data) {
        let file: DriveFile
        if let existingFileID, !existingFileID.isEmpty {
            do {
                file = try await getFileMetadata(id: existingFileID)
            } catch GoogleDriveSyncError.server(let statusCode, _) where statusCode == 404 {
                file = try await findCloudBackupFile()
            }
        } else {
            file = try await findCloudBackupFile()
        }

        let data = try await downloadFile(id: file.id)
        return (file.cloudBackupFile, data)
    }

    func downloadCloudBackup(fileID: String) async throws -> (file: GoogleDriveCloudBackupFile, data: Data) {
        let file = try await getFileMetadata(id: fileID)
        let data = try await downloadFile(id: file.id)
        return (file.cloudBackupFile, data)
    }

    func listCloudBackups() async throws -> [GoogleDriveCloudBackupFile] {
        guard let rootFolder = try await findFile(named: Self.rootFolderName, mimeType: Self.folderMimeType, parentID: nil) else {
            return []
        }

        var files = try await findBackupFiles(parentID: rootFolder.id)
        let monthFolders = try await findFiles(mimeType: Self.folderMimeType, parentID: rootFolder.id)
        for folder in monthFolders {
            files.append(contentsOf: try await findBackupFiles(parentID: folder.id))
        }

        let uniqueFiles = Dictionary(grouping: files, by: \.id)
            .compactMap { $0.value.first }
            .sorted { ($0.modifiedTime ?? "") > ($1.modifiedTime ?? "") }
        return uniqueFiles.map(\.cloudBackupFile)
    }

    func uploadDocumentFile(
        data: Data,
        fileName: String,
        mimeType: String,
        folderName: String,
        existingFileID: String?
    ) async throws -> GoogleDriveCloudBackupFile {
        let rootFolder = try await findOrCreateFolder(named: Self.rootFolderName, parentID: nil)
        let typeFolder = try await findOrCreateFolder(named: folderName, parentID: rootFolder.id)
        let file = try await uploadOrUpdateFile(
            name: fileName,
            mimeType: mimeType,
            data: data,
            parentID: typeFolder.id,
            existingFileID: existingFileID
        )
        return file.cloudBackupFile
    }

    private func findCloudBackupFile() async throws -> DriveFile {
        guard let rootFolder = try await findFile(named: Self.rootFolderName, mimeType: Self.folderMimeType, parentID: nil),
              let backupFile = try await newestBackupFile(in: rootFolder.id) else {
            throw GoogleDriveSyncError.cloudBackupNotFound
        }
        return backupFile
    }

    private func newestBackupFile(in rootFolderID: String) async throws -> DriveFile? {
        let directFiles = try await findBackupFiles(parentID: rootFolderID)
        let monthFolders = try await findFiles(mimeType: Self.folderMimeType, parentID: rootFolderID)
        var files = directFiles
        for folder in monthFolders {
            files.append(contentsOf: try await findBackupFiles(parentID: folder.id))
        }
        return files.sorted { ($0.modifiedTime ?? "") > ($1.modifiedTime ?? "") }.first
    }

    private func findOrCreateFolder(named name: String, parentID: String?) async throws -> DriveFile {
        if let existingFolder = try await findFile(named: name, mimeType: Self.folderMimeType, parentID: parentID) {
            return existingFolder
        }

        var metadata: [String: Any] = [
            "name": name,
            "mimeType": Self.folderMimeType,
        ]
        if let parentID {
            metadata["parents"] = [parentID]
        }

        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "fields", value: "id,name,mimeType,modifiedTime"),
        ]

        var request = authorizedRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: metadata)
        return try await send(request, expecting: DriveFile.self)
    }

    private func uploadOrUpdateFile(
        name: String,
        mimeType: String,
        data: Data,
        parentID: String,
        existingFileID: String?
    ) async throws -> DriveFile {
        if let existingFileID, !existingFileID.isEmpty {
            do {
                return try await updateFile(id: existingFileID, name: name, mimeType: mimeType, data: data)
            } catch GoogleDriveSyncError.server(let statusCode, _) where statusCode == 404 {
            }
        }

        if let duplicate = try await findFile(named: name, mimeType: mimeType, parentID: parentID) {
            return try await updateFile(id: duplicate.id, name: name, mimeType: mimeType, data: data)
        }

        return try await createFile(name: name, mimeType: mimeType, data: data, parentID: parentID)
    }

    private func createFile(name: String, mimeType: String, data: Data, parentID: String) async throws -> DriveFile {
        let metadata: [String: Any] = [
            "name": name,
            "mimeType": mimeType,
            "parents": [parentID],
        ]
        var components = URLComponents(string: "https://www.googleapis.com/upload/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "uploadType", value: "multipart"),
            URLQueryItem(name: "fields", value: "id,name,mimeType,modifiedTime,size"),
        ]

        let boundary = "shoko_boundary_\(UUID().uuidString)"
        var request = authorizedRequest(url: components.url!)
        request.httpMethod = "POST"
        request.httpBody = try multipartBody(metadata: metadata, mediaData: data, mediaMimeType: mimeType, boundary: boundary)
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("\(request.httpBody?.count ?? 0)", forHTTPHeaderField: "Content-Length")
        return try await send(request, expecting: DriveFile.self)
    }

    private func updateFile(id fileID: String, name: String, mimeType: String, data: Data) async throws -> DriveFile {
        let metadata: [String: Any] = [
            "name": name,
            "mimeType": mimeType,
        ]
        let encodedFileID = fileID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileID
        var components = URLComponents(string: "https://www.googleapis.com/upload/drive/v3/files/\(encodedFileID)")!
        components.queryItems = [
            URLQueryItem(name: "uploadType", value: "multipart"),
            URLQueryItem(name: "fields", value: "id,name,mimeType,modifiedTime,size"),
        ]

        let boundary = "shoko_boundary_\(UUID().uuidString)"
        var request = authorizedRequest(url: components.url!)
        request.httpMethod = "PATCH"
        request.httpBody = try multipartBody(metadata: metadata, mediaData: data, mediaMimeType: mimeType, boundary: boundary)
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("\(request.httpBody?.count ?? 0)", forHTTPHeaderField: "Content-Length")
        return try await send(request, expecting: DriveFile.self)
    }

    private func getFileMetadata(id fileID: String) async throws -> DriveFile {
        let encodedFileID = fileID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileID
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files/\(encodedFileID)")!
        components.queryItems = [
            URLQueryItem(name: "fields", value: "id,name,mimeType,modifiedTime,size"),
        ]
        return try await send(authorizedRequest(url: components.url!), expecting: DriveFile.self)
    }

    private func downloadFile(id fileID: String) async throws -> Data {
        let encodedFileID = fileID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileID
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files/\(encodedFileID)")!
        components.queryItems = [
            URLQueryItem(name: "alt", value: "media"),
        ]
        return try await sendData(authorizedRequest(url: components.url!))
    }

    private func findFile(named name: String, mimeType: String, parentID: String?) async throws -> DriveFile? {
        let parent = parentID ?? "root"
        let query = [
            "name = '\(escapedDriveQueryValue(name))'",
            "mimeType = '\(escapedDriveQueryValue(mimeType))'",
            "'\(escapedDriveQueryValue(parent))' in parents",
            "trashed = false",
        ].joined(separator: " and ")

        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "spaces", value: "drive"),
            URLQueryItem(name: "pageSize", value: "1"),
            URLQueryItem(name: "orderBy", value: "modifiedTime desc"),
            URLQueryItem(name: "fields", value: "files(id,name,mimeType,modifiedTime)"),
        ]

        let response = try await send(authorizedRequest(url: components.url!), expecting: DriveFileListResponse.self)
        return response.files.first
    }

    private func findFiles(mimeType: String, parentID: String) async throws -> [DriveFile] {
        let query = [
            "mimeType = '\(escapedDriveQueryValue(mimeType))'",
            "'\(escapedDriveQueryValue(parentID))' in parents",
            "trashed = false",
        ].joined(separator: " and ")

        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "spaces", value: "drive"),
            URLQueryItem(name: "pageSize", value: "100"),
            URLQueryItem(name: "orderBy", value: "modifiedTime desc"),
            URLQueryItem(name: "fields", value: "files(id,name,mimeType,modifiedTime,size)"),
        ]

        let response = try await send(authorizedRequest(url: components.url!), expecting: DriveFileListResponse.self)
        return response.files
    }

    private func findBackupFiles(parentID: String) async throws -> [DriveFile] {
        let backupFilter = [
            "mimeType = '\(escapedDriveQueryValue(Self.backupMimeType))'",
            "name contains '.shokobackup'",
            "name contains 'shoko-forms-backup'",
            "name = '\(escapedDriveQueryValue(Self.legacyBackupFileName))'",
        ].joined(separator: " or ")
        let query = [
            "(\(backupFilter))",
            "'\(escapedDriveQueryValue(parentID))' in parents",
            "trashed = false",
        ].joined(separator: " and ")

        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "spaces", value: "drive"),
            URLQueryItem(name: "pageSize", value: "100"),
            URLQueryItem(name: "orderBy", value: "modifiedTime desc"),
            URLQueryItem(name: "fields", value: "files(id,name,mimeType,modifiedTime,size)"),
        ]

        let response = try await send(authorizedRequest(url: components.url!), expecting: DriveFileListResponse.self)
        return response.files
    }

    private static func currentMonthFolderName() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    private static func backupFileName() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "shoko-forms-backup-\(formatter.string(from: Date())).shokobackup"
    }

    private func authorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, expecting type: T.Type) async throws -> T {
        let data = try await sendData(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GoogleDriveSyncError.invalidDriveResponse
        }
    }

    private func sendData(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if error.code == .notConnectedToInternet || error.code == .timedOut || error.code == .networkConnectionLost {
                throw GoogleDriveSyncError.networkUnavailable
            }
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleDriveSyncError.invalidDriveResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw GoogleDriveSyncError.tokenExpired
            }
            let message = driveErrorMessage(from: data)
            if httpResponse.statusCode == 403, isDriveAPIDisabledMessage(message) {
                throw GoogleDriveSyncError.driveAPIUnavailable(projectID: driveProjectID(from: message))
            }
            throw GoogleDriveSyncError.server(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }
        return data
    }

    private func multipartBody(metadata: [String: Any], mediaData: Data, mediaMimeType: String, boundary: String) throws -> Data {
        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Type: application/json; charset=UTF-8\r\n\r\n")
        body.append(try JSONSerialization.data(withJSONObject: metadata, options: []))
        body.appendUTF8("\r\n--\(boundary)\r\n")
        body.appendUTF8("Content-Type: \(mediaMimeType)\r\n\r\n")
        body.append(mediaData)
        body.appendUTF8("\r\n--\(boundary)--\r\n")
        return body
    }

    private func driveErrorMessage(from data: Data) -> String {
        guard !data.isEmpty,
              let response = try? JSONDecoder().decode(DriveErrorResponse.self, from: data),
              let message = response.error?.message,
              !message.isEmpty else {
            return "Google Drive request failed."
        }
        return message
    }

    private func isDriveAPIDisabledMessage(_ message: String) -> Bool {
        message.contains("Drive API has not been used") ||
            message.contains("drive.googleapis.com") && message.contains("disabled")
    }

    private func driveProjectID(from message: String) -> String? {
        if let range = message.range(of: "project ") {
            let suffix = message[range.upperBound...]
            let projectID = suffix.prefix { $0.isNumber }
            if !projectID.isEmpty {
                return String(projectID)
            }
        }
        if let range = message.range(of: "project=") {
            let suffix = message[range.upperBound...]
            let projectID = suffix.prefix { $0.isNumber }
            if !projectID.isEmpty {
                return String(projectID)
            }
        }
        return nil
    }

    private func escapedDriveQueryValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}

private struct DriveFile: Decodable {
    let id: String
    let name: String?
    let mimeType: String?
    let modifiedTime: String?
    let size: String?

    var cloudBackupFile: GoogleDriveCloudBackupFile {
        GoogleDriveCloudBackupFile(fileId: id, name: name ?? "", modifiedTime: modifiedTime, size: size.flatMap(Int64.init))
    }
}

private struct DriveFileListResponse: Decodable {
    let files: [DriveFile]
}

private struct DriveErrorResponse: Decodable {
    let error: DriveErrorBody?
}

private struct DriveErrorBody: Decodable {
    let message: String?
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}

private extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presentedViewController {
            return presentedViewController.topMostViewController()
        }
        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.topMostViewController()
        }
        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.topMostViewController()
        }
        return self
    }
}

private extension DocumentType {
    var googleDriveFolderName: String {
        switch self {
        case .estimate, .vendorEstimate:
            return "見積書"
        case .invoice, .vendorInvoice, .paymentNotice:
            return "請求書"
        case .delivery, .acceptance:
            return "納品書"
        case .receipt, .vendorReceipt:
            return "領収書"
        default:
            return localizedTitle(.japanese)
        }
    }
}

import Foundation

public enum ProcessState: String, Codable, Equatable, Sendable {
    case starting
    case running
    case exited
}

public struct TerminalPane: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var cwd: String
    public var shellPath: String
    public var processState: ProcessState
    public var isActive: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        cwd: String,
        shellPath: String,
        processState: ProcessState = .starting,
        isActive: Bool = false
    ) {
        self.id = id
        self.title = title
        self.cwd = cwd
        self.shellPath = shellPath
        self.processState = processState
        self.isActive = isActive
    }
}

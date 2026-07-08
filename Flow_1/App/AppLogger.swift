//
//  AppLogger.swift
//  Flow_1
//
//  Created for Logging System
//

import Foundation
import os

enum LogLevel: String {
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case crash = "CRASH"
    
    var prefix: String {
        switch self {
        case .info: return "🟢 [INFO]"
        case .warning: return "🟠 [WARNING]"
        case .error: return "🔴 [ERROR]"
        case .crash: return "💥 [CRASH]"
        }
    }
}

class AppLogger {
    static let shared = AppLogger()
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()
    
    private let logQueue = DispatchQueue(label: "com.libriai.logger", qos: .background)
    private let fileManager = FileManager.default
    private var currentLogURL: URL?
    private var persistentFileHandle: FileHandle?
    
    var logFileURL: URL? {
        return currentLogURL
    }
    private let osLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.libriai.Flow-1", category: "AppLog")
    
    private init() {
        setupLogFile()
        cleanupOldLogs()
        setupCrashHandler()
    }
    
    /// Initializes a new log file for the current session
    private func setupLogFile() {
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let logsDir = docsURL.appendingPathComponent("AppLogs", isDirectory: true)
        
        if !fileManager.fileExists(atPath: logsDir.path) {
            try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "AppLog_\(dateString).txt"
        
        let logURL = logsDir.appendingPathComponent(fileName)
        
        // Create an empty file
        fileManager.createFile(atPath: logURL.path, contents: Data(), attributes: nil)
        self.currentLogURL = logURL
        openPersistentHandle()
        
        self.info("Log session started. File: \(fileName)")
    }
    
    /// Retains only the last 7 days of logs
    private func cleanupOldLogs() {
        logQueue.async { [weak self] in
            guard let self = self,
                  let docsURL = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let logsDir = docsURL.appendingPathComponent("AppLogs", isDirectory: true)
            
            do {
                let fileURLs = try self.fileManager.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
                let thresholdDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                
                for fileURL in fileURLs {
                    let resources = try fileURL.resourceValues(forKeys: [.creationDateKey])
                    if let creationDate = resources.creationDate, creationDate < thresholdDate {
                        try self.fileManager.removeItem(at: fileURL)
                        self.osLogger.info("Deleted old log file: \(fileURL.lastPathComponent)")
                    }
                }
            } catch {
                self.osLogger.error("Failed to clean up old logs: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Logging API
    
    func clearLogs() {
        guard let url = currentLogURL else { return }
        logQueue.async {
            do {
                try "".write(to: url, atomically: true, encoding: .utf8)
                self.osLogger.info("Logs cleared by user.")
            } catch {
                self.osLogger.error("Failed to clear logs: \(error.localizedDescription)")
            }
        }
    }
    
    func info(_ message: String) {
        log(level: .info, message: message)
    }
    
    func warning(_ message: String) {
        log(level: .warning, message: message)
    }
    
    func error(_ message: String) {
        log(level: .error, message: message)
    }
    
    func crash(_ message: String) {
        log(level: .crash, message: message)
    }
    
    private func openPersistentHandle() {
        guard let url = currentLogURL else { return }
        logQueue.async { [weak self] in
            self?.persistentFileHandle = try? FileHandle(forWritingTo: url)
            self?.persistentFileHandle?.seekToEndOfFile()
        }
    }
    
    private func log(level: LogLevel, message: String) {
        let timestamp = Self.isoFormatter.string(from: Date())
        let formattedMessage = "\(timestamp) | \(level.prefix) \(message)"
        
        // Print to Xcode console
        switch level {
        case .info: osLogger.info("\(message, privacy: .public)")
        case .warning: osLogger.warning("\(message, privacy: .public)")
        case .error: osLogger.error("\(message, privacy: .public)")
        case .crash: osLogger.fault("\(message, privacy: .public)")
        }
        
        // Write to file asynchronously using persistent handle
        logQueue.async { [weak self] in
            guard let handle = self?.persistentFileHandle else { return }
            if let data = (formattedMessage + "\n").data(using: .utf8) {
                handle.write(data)
            }
        }
    }
    
    // MARK: - Crash Handling
    
    /// Sets up basic Objective-C exception handling to catch uncaught exceptions
    private func setupCrashHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let stackTrace = exception.callStackSymbols.joined(separator: "\n")
            let crashMessage = """
            Uncaught Exception:
            Name: \(exception.name)
            Reason: \(exception.reason ?? "Unknown")
            Stack Trace:
            \(stackTrace)
            """
            
            // Because we are crashing, write synchronously on main thread to ensure it's saved
            if let url = AppLogger.shared.currentLogURL {
                let timestamp = ISO8601DateFormatter().string(from: Date())
                let formattedMessage = "\(timestamp) | 💥 [CRASH] \(crashMessage)\n"
                if let data = formattedMessage.data(using: .utf8),
                   let fileHandle = try? FileHandle(forWritingTo: url) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            }
        }
    }
}

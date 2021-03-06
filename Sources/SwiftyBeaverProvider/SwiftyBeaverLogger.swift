//
//  SwiftyBeaverLogger.swift
//  SwiftyBeaverProvider
//
//  Created by Gustavo Perdomo on 5/2/17.
//  Copyright © 2017 Gustavo Perdomo. All rights reserved.
//

import Vapor
import SwiftyBeaver
import Foundation

fileprivate let configFileName = "swiftybeaver"

public final class SwiftyBeaverLogger: LogProtocol {
    public var enabled: [LogLevel]
    private var sb: SwiftyBeaver.Type = SwiftyBeaver.self

    public init(destinations: [BaseDestination]) {
        for destination in destinations {
            sb.addDestination(destination)
        }
        enabled = LogLevel.all
    }

    public func log(_ level: LogLevel, message: String, file: String, function: String, line: Int) {
        if enabled.contains(level) {
            // log to SwiftyBeaver
            sb.custom(level: level.sbStyle, message: message, file: file, function: function, line: line)
        }
    }
}

extension SwiftyBeaverLogger: ConfigInitializable {
    public convenience init(config: Config) throws {
        guard let swiftybeaver = config[configFileName]?.object else {
            throw ConfigError.missingFile(configFileName)
        }

        var destinations = [BaseDestination]()

        if swiftybeaver["console"]?.bool != nil {
            let console = ConsoleDestination()
            if let format = swiftybeaver["console_format"]?.string, !format.isEmpty && !format.isNull {
                console.format = format
            }
            destinations.append(console)
        }

        if let path = swiftybeaver["file"]?.string {
            guard !path.isEmpty && !path.isNull else {
                throw ConfigError.unsupported(value: path, key: [path], file: configFileName)
            }

            let file = FileDestination()  // log to file
            if let format = swiftybeaver["file_format"]?.string, !format.isEmpty && !format.isNull {
                file.format = format
            }
            file.logFileURL = URL(fileURLWithPath: path) // set log file
            destinations.append(file)
        }

        if let platform = swiftybeaver["platform"]?.object {
            guard let appId = platform["appId"]?.string else {
                throw ConfigError.missing(key: ["appId"], file: configFileName, desiredType: String.self)
            }

            guard !appId.isEmpty && !appId.isNull else {
                throw ConfigError.unsupported(value: appId, key: ["appId"], file: configFileName)
            }

            guard let appSecret = platform["appSecret"]?.string else {
                throw ConfigError.missing(key: ["appSecret"], file: configFileName, desiredType: String.self)
            }

            guard !appSecret.isEmpty && !appSecret.isNull else {
                throw ConfigError.unsupported(value: appSecret, key: ["appSecret"], file: configFileName)
            }

            guard let encryptionKey = platform["encryptionKey"]?.string else {
                throw ConfigError.missing(key: ["encryptionKey"], file: configFileName, desiredType: String.self)
            }

            guard !encryptionKey.isEmpty && !encryptionKey.isNull else {
                throw ConfigError.unsupported(value: encryptionKey, key: ["encryptionKey"], file: configFileName)
            }

            let sbp = SBPlatformDestination(appID: appId, appSecret: appSecret, encryptionKey: encryptionKey)

            destinations.append(sbp)
        }

        guard !destinations.isEmpty else {
            throw SwiftyBeaverProviderError.missingDestinations
        }

        self.init(destinations: destinations)
    }
}

extension LogLevel {
    var sbStyle: SwiftyBeaver.Level {
        switch self {
        case .verbose:
            return .verbose
        case .debug, .custom(_):
            return .debug
        case .info:
            return .info
        case .warning:
            return .warning
        case .error, .fatal:
            return .error
        }
    }
}

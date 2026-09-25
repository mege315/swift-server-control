import Vapor
import Foundation

struct PowerCommand: Content {
    let action: String
}

struct FanCommand: Content {
    let speed: Int
}

struct TemperatureResponse: Content {
    let celsius: Double
}

struct BatteryResponse: Content {
    let capacity: Int
    let status: String
}

struct MemoryResponse: Content {
    let totalMB: Int
    let availableMB: Int
    let usedMB: Int
}

struct SystemStatusResponse: Content {
    let uptimeSeconds: Double
    let load1: Double
    let load5: Double
    let load15: Double
}

struct DiskResponse: Content {
    let totalGB: Double
    let freeGB: Double
    let usedGB: Double
}

struct SystemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("power", use: managePower)
        routes.post("fan", use: setFanSpeed)
        routes.get("temperature", use: getTemperature)
        routes.get("api", "v1", "system", "temperature", use: getTemperature)
        routes.get("battery", use: getBattery)
        routes.get("api", "v1", "system", "battery", use: getBattery)
        routes.get("memory", use: getMemory)
        routes.get("api", "v1", "system", "memory", use: getMemory)
        routes.get("status", use: getStatus)
        routes.get("api", "v1", "system", "status", use: getStatus)
        routes.get("disk", use: getDisk)
        routes.get("api", "v1", "system", "disk", use: getDisk)
    }

    @Sendable
    func managePower(req: Request) async throws -> String {
        let command = try req.content.decode(PowerCommand.self)

        let arguments: [String]
        switch command.action {
        case "reboot":
            arguments = ["reboot"]
        case "shutdown":
            arguments = ["shutdown", "now"]
        default:
            throw Abort(.badRequest, reason: "Invalid action. Supported actions: reboot, shutdown")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = arguments

        try process.run()

        return "Command '\(command.action)' executed successfully."
    }

    @Sendable
    func setFanSpeed(req: Request) async throws -> String {
        guard let pwmPath = findPWMPath() else {
            throw Abort(.notFound, reason: "No controllable fan (PWM) sensor found on the system.")
        }

        let command = try req.content.decode(FanCommand.self)

        guard (0...255).contains(command.speed) else {
            throw Abort(.badRequest, reason: "Speed must be between 0 and 255.")
        }

        do {
            try String(command.speed).write(toFile: pwmPath, atomically: false, encoding: .utf8)
        } catch {
            throw Abort(.internalServerError)
        }

        return "Fan speed successfully set to \(command.speed)."
    }

    @Sendable
    func getTemperature(req: Request) async throws -> TemperatureResponse {
        guard let tempPath = getCoreTempPath() else {
            throw Abort(.notFound)
        }

        guard let content = try? String(contentsOfFile: tempPath, encoding: .utf8) else {
            throw Abort(.internalServerError)
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let milliCelsius = Double(trimmed) else {
            throw Abort(.internalServerError)
        }

        let celsius = milliCelsius / 1000.0
        return TemperatureResponse(celsius: celsius)
    }

    @Sendable
    func getBattery(req: Request) async throws -> BatteryResponse {
        guard let batteryPath = findBatteryPath() else {
            throw Abort(.notFound, reason: "Battery not found.")
        }

        let capacityPath = "\(batteryPath)/capacity"
        let statusPath = "\(batteryPath)/status"

        guard let capacityString = try? String(contentsOfFile: capacityPath, encoding: .utf8),
              let capacity = Int(capacityString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw Abort(.internalServerError)
        }

        guard let statusString = try? String(contentsOfFile: statusPath, encoding: .utf8) else {
            throw Abort(.internalServerError)
        }

        let status = statusString.trimmingCharacters(in: .whitespacesAndNewlines)

        return BatteryResponse(capacity: capacity, status: status)
    }

    @Sendable
    func getMemory(req: Request) async throws -> MemoryResponse {
        guard let meminfo = try? String(contentsOfFile: "/proc/meminfo", encoding: .utf8) else {
            throw Abort(.internalServerError, reason: "Memory information could not be read.")
        }

        var memTotalKB: Int?
        var memAvailableKB: Int?

        let lines = meminfo.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix("MemTotal:") {
                let digits = line.filter { $0.isNumber }
                memTotalKB = Int(digits)
            } else if line.hasPrefix("MemAvailable:") {
                let digits = line.filter { $0.isNumber }
                memAvailableKB = Int(digits)
            }
        }

        guard let totalKB = memTotalKB, let availableKB = memAvailableKB else {
            throw Abort(.internalServerError, reason: "Failed to parse memory information.")
        }

        let totalMB = totalKB / 1024
        let availableMB = availableKB / 1024
        let usedMB = totalMB - availableMB

        return MemoryResponse(totalMB: totalMB, availableMB: availableMB, usedMB: usedMB)
    }

    @Sendable
    func getStatus(req: Request) async throws -> SystemStatusResponse {
        guard let uptimeContent = try? String(contentsOfFile: "/proc/uptime", encoding: .utf8) else {
            throw Abort(.internalServerError, reason: "Uptime data could not be read.")
        }

        let uptimeParts = uptimeContent.split(separator: " ")
        guard let firstUptimePart = uptimeParts.first,
              let uptimeSeconds = Double(firstUptimePart) else {
            throw Abort(.internalServerError, reason: "Uptime data could not be read.")
        }

        guard let loadavgContent = try? String(contentsOfFile: "/proc/loadavg", encoding: .utf8) else {
            throw Abort(.internalServerError, reason: "Load average data could not be read.")
        }

        let loadParts = loadavgContent.split(separator: " ")
        guard loadParts.count >= 3,
              let load1 = Double(loadParts[0]),
              let load5 = Double(loadParts[1]),
              let load15 = Double(loadParts[2]) else {
            throw Abort(.internalServerError, reason: "Load average data could not be read.")
        }

        return SystemStatusResponse(uptimeSeconds: uptimeSeconds, load1: load1, load5: load5, load15: load15)
    }

    @Sendable
    func getDisk(req: Request) async throws -> DiskResponse {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/") else {
            throw Abort(.internalServerError, reason: "Disk information could not be read.")
        }

        guard let systemSize = attributes[.systemSize] as? NSNumber,
              let systemFreeSize = attributes[.systemFreeSize] as? NSNumber else {
            throw Abort(.internalServerError, reason: "Disk information could not be read.")
        }

        let bytesPerGB: Double = 1_073_741_824.0
        let totalGB = ((systemSize.doubleValue / bytesPerGB) * 100.0).rounded() / 100.0
        let freeGB = ((systemFreeSize.doubleValue / bytesPerGB) * 100.0).rounded() / 100.0
        let usedGB = ((totalGB - freeGB) * 100.0).rounded() / 100.0

        return DiskResponse(totalGB: totalGB, freeGB: freeGB, usedGB: usedGB)
    }

    private func findBatteryPath() -> String? {
        let fileManager = FileManager.default
        let powerSupplyBasePath = "/sys/class/power_supply"

        guard let dirs = try? fileManager.contentsOfDirectory(atPath: powerSupplyBasePath) else {
            return nil
        }

        for dir in dirs.sorted() {
            if dir.hasPrefix("BAT") {
                return "\(powerSupplyBasePath)/\(dir)"
            }
        }

        return nil
    }

    private func getCoreTempPath() -> String? {
        let fileManager = FileManager.default
        let hwmonBasePath = "/sys/class/hwmon"

        guard let hwmonDirs = try? fileManager.contentsOfDirectory(atPath: hwmonBasePath) else {
            return nil
        }

        for dir in hwmonDirs.sorted() {
            let dirPath = "\(hwmonBasePath)/\(dir)"
            let namePath = "\(dirPath)/name"

            if let name = try? String(contentsOfFile: namePath, encoding: .utf8) {
                if name.trimmingCharacters(in: .whitespacesAndNewlines) == "coretemp" {
                    return "\(dirPath)/temp1_input"
                }
            }
        }

        return nil
    }

    private func findPWMPath() -> String? {
        let fileManager = FileManager.default
        let hwmonBasePath = "/sys/class/hwmon"

        guard let hwmonDirs = try? fileManager.contentsOfDirectory(atPath: hwmonBasePath) else {
            return nil
        }

        for dir in hwmonDirs.sorted() {
            let dirPath = "\(hwmonBasePath)/\(dir)"
            guard let files = try? fileManager.contentsOfDirectory(atPath: dirPath) else {
                continue
            }

            for file in files.sorted() {
                if file.contains("pwm") {
                    return "\(dirPath)/\(file)"
                }
            }
        }

        return nil
    }
}

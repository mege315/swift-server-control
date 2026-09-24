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

struct SystemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("power", use: managePower)
        routes.post("fan", use: setFanSpeed)
        routes.get("temperature", use: getTemperature)
        routes.get("api", "v1", "system", "temperature", use: getTemperature)
        routes.get("battery", use: getBattery)
        routes.get("api", "v1", "system", "battery", use: getBattery)
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

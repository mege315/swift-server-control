import Vapor
import Foundation

struct PowerCommand: Content {
    let action: String
}

struct FanCommand: Content {
    let speed: Int
}

struct SystemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("power", use: managePower)
        routes.post("fan", use: setFanSpeed)
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

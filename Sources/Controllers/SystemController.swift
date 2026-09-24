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
        let command = try req.content.decode(FanCommand.self)

        guard (0...255).contains(command.speed) else {
            throw Abort(.badRequest, reason: "Speed must be between 0 and 255.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["sh", "-c", "echo \(command.speed) > /sys/class/hwmon/hwmon0/pwm1"]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw Abort(.internalServerError)
        }

        guard process.terminationStatus == 0 else {
            throw Abort(.internalServerError)
        }

        return "Fan speed successfully set to \(command.speed)."
    }
}

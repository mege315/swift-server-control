import Vapor
import Foundation

struct BatteryStatus: Content {
    let percentage: Int
    let isCharging: Bool
}

struct BatteryController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("battery", use: getBatteryStatus)
    }

    @Sendable
    func getBatteryStatus(req: Request) async throws -> BatteryStatus {
        let capacityPath = "/sys/class/power_supply/BAT0/capacity"
        let statusPath = "/sys/class/power_supply/BAT0/status"

        var percentage = 0
        var isCharging = false

        if let capacityRaw = try? String(contentsOfFile: capacityPath) {
            let trimmedCapacity = capacityRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            percentage = Int(trimmedCapacity) ?? 0
        }

        if let statusRaw = try? String(contentsOfFile: statusPath) {
            let trimmedStatus = statusRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            isCharging = (trimmedStatus == "Charging")
        }

        return BatteryStatus(percentage: percentage, isCharging: isCharging)
    }
}

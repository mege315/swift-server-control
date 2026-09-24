import Vapor

struct SystemController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("fan", use: handleFan)
        routes.post("power", use: handlePower)
    }

    @Sendable
    func handleFan(req: Request) async throws -> String {
        return "Fan command received"
    }

    @Sendable
    func handlePower(req: Request) async throws -> String {
        return "Power command received"
    }
}

import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "Server is online!"
    }

    let api = app.grouped("api", "v1")

    let hardware = api.grouped("hardware")
    let system = api.grouped("system")

    try hardware.register(collection: BatteryController())
    try system.register(collection: SystemController())
}

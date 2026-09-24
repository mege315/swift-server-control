import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = Application(env)
defer { app.shutdown() }

// Configure hostname and port for external access (e.g., Tailscale)
app.http.server.configuration.hostname = "0.0.0.0"
app.http.server.configuration.port = 8080

// Register routes
try routes(app)

// Run application
try app.run()
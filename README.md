# Swift Server Control

**Swift Server Control** is a lightweight REST API built with Server-side Swift (Vapor 4). Designed for headless Ubuntu Linux environments, it provides direct network access to system hardware telemetry and management.

By directly reading from the Linux `/sys/class/` file system, the API serves real-time data such as battery capacity and charging status, with planned extensibility for PWM fan control and system power management. It is optimized for secure, local network execution (e.g., via Tailscale).

### Tech Stack
- **Language:** Swift 5.10+
- **Framework:** Vapor 4
- **Environment:** Ubuntu Server / Headless Linux
- **Architecture:** Controller-based REST API


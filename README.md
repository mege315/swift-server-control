# Swift Server Control

**Swift Server Control** is a lightweight REST API built with Server-side Swift (Vapor 4). Designed for headless Ubuntu Linux environments, it provides direct network access to system hardware telemetry and management.

By directly reading from the Linux `/sys/class/` file system, the API serves real-time data such as battery capacity and charging status, with planned extensibility for PWM fan control and system power management. It is optimized for secure, local network execution (e.g., via Tailscale).

## System Configuration for Power Management

To allow the API to safely manage system power states (reboot/shutdown) without requiring an interactive password prompt, you must grant passwordless `sudo` execution specifically for those two commands.

Run the following command on your host machine to create a secure drop-in sudoers rule (replace `mege` with your actual Linux username):

Run the following command on your host machine to create a secure drop-in sudoers rule (replace `mege` with your actual Linux username):

```bash
echo "mege ALL=(ALL) NOPASSWD: /sbin/reboot, /sbin/shutdown" | sudo tee /etc/sudoers.d/vapor_power
```

> **Security Note:** This configuration strictly limits passwordless elevation to `/sbin/reboot` and `/sbin/shutdown`, maintaining the security of the host system.

### Hardware Fan Control (Optional)

For devices that expose PWM fan control via `sysfs` (e.g., Raspberry Pi, desktop motherboards), the API requires write permissions to the hardware monitoring nodes. Instead of running the entire Vapor server as root, it is recommended to apply a `udev` rule to grant necessary permissions dynamically.

Run the following commands to create and apply the rule:

```bash
echo 'ACTION=="add", SUBSYSTEM=="hwmon", RUN+="/bin/chmod 666 /sys/class/hwmon/%k/pwm*"' | sudo tee /etc/udev/rules.d/99-fan-control.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

> **Note:** Many enterprise laptops (like HP EliteBooks) lock fan control to the Embedded Controller (EC) and ACPI. On such devices, the API will safely return a `500 Internal Server Error` rather than attempting unsafe register modifications.

### Tech Stack
- **Language:** Swift 5.10+
- **Framework:** Vapor 4
- **Environment:** Ubuntu Server / Headless Linux
- **Architecture:** Controller-based REST API


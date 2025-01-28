# SSHMenu

SSHMenu is a powerful and user-friendly SSH session manager, originally based on **SSHTo** by [Ivan](https://github.com/vaniacer/sshto). It provides an interactive terminal UI for managing SSH connections efficiently. This project expands on the original tool by adding several improvements and new features.

## Features & Improvements

- **Refactored BASH Math Functions**
- **Support for Multiple SSH Config Files**
- **Automated Installation Script** (allows SSHMenu to run from anywhere)
- **Dynamic SSH Configuration Handling**
- **New Command Line Arguments:**
  - `--config`: Launches a built-in configuration editor
  - `--refresh`: Updates the SSH configuration dynamically
  - `--list-hosts`: Lists all available SSH hosts
  - `--check-deps`: Checks for missing dependencies
- **Interactive SSHMenu Configuration Editor**
  - Modify settings within the SSHMenu interface
  - No need to manually edit config files
- **Persistent Configuration Handling**
  - Stores and maintains `.sshmenurc`
  - Ensures proper permissions & security

---

## Installation

### **Quick Install:**
Run the following commands:
```bash
curl -sSL https://raw.githubusercontent.com/girls-whocode/sshmenu/main/install.sh | bash
```
This will:
- Copy the `sshmenu.sh` script to `~/.local/bin/sshmenu`
- Ensure it is executable (`chmod +x`)
- Add `~/.local/bin` to the user's `$PATH` (if necessary)

### **Manual Install:**
1. Clone the repository:
   ```bash
   git clone https://github.com/girls-whocode/sshmenu.git
   cd sshmenu
   ```
2. Run the installer:
   ```bash
   ./install.sh
   ```
3. Restart your terminal or run:
   ```bash
   source ~/.bashrc  # or ~/.zshrc if using Zsh
   ```

---

## Usage

Launch SSHMenu by typing:
```bash
sshmenu
```

### **Command-Line Arguments:**
| Command | Description |
|---------|-------------|
| `--config` | Open the SSHMenu configuration editor |
| `--refresh` | Refresh the list of SSH configuration files |
| `--list-hosts` | List all SSH hosts from config files |
| `--check-deps` | Check if all required dependencies are installed |
| `--uninstall` | Uninstall sshmenu |
| `--help` | Shows the arguments that can be used |

### **Example: View All SSH Hosts**
```bash
sshmenu --list-hosts
```

### **Example: Edit SSHMenu Configuration**
```bash
sshmenu --config
```

---

## Configuration

SSHMenu stores user settings in `~/.sshmenurc`. You can edit this manually or use:
```bash
sshmenu --config
```

Example of `.sshmenurc`:
```ini
# SSHMenu Configuration File
home=/home/user
OPT=
KEY=/home/user/.ssh/id_rsa.pub
CONFILES="/home/user/.ssh/config /home/user/.ssh/config.d/work"
REMOTE=8080
LOCAL=18080
GUEST=user
DEST="/home/user"
TIME=60
EDITOR=nano
LSEXIT=true
knwhosts=/home/user/.ssh/known_hosts
confile=/home/user/.sshmenurc
```

---

## Uninstallation
To uninstall SSHMenu, run:
```bash
sshmenu --uninstall
```
This will:
- Remove `sshmenu.sh` from `~/.local/bin/`
- Delete the configuration file (`~/.sshmenurc`)
- Remove the `$PATH` entry if necessary

---

## Dependencies
SSHMenu requires the following packages:
- `dialog`
- `gawk`

To check dependencies manually:
```bash
sshmenu --check-deps
```
If any are missing, SSHMenu will suggest installation commands.

---

## Acknowledgments
SSHMenu was inspired by [Ivan's SSHTo](https://github.com/vaniacer/sshto). His work laid the foundation for this project, and this version builds upon his vision with additional features and improvements.

---

## License
SSHMenu is released under the [MIT License](LICENSE).

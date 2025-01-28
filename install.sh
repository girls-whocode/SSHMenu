#!/bin/bash

INSTALL_DIR="$HOME/.local/bin"
SYSTEM_INSTALL=false
SCRIPT_URL="https://raw.githubusercontent.com/girls-whocode/sshmenu/main/sshmenu.sh"
SCRIPT_NAME="sshmenu"

# Detect if running as root, install to /usr/local/bin
if [[ $EUID -eq 0 ]]; then
    INSTALL_DIR="/usr/local/bin"
    SYSTEM_INSTALL=true
fi

echo "🔹 Installing SSHMenu to $INSTALL_DIR..."

# Ensure the install directory exists
mkdir -p "$INSTALL_DIR"

# Download sshmenu.sh
echo "🔹 Downloading SSHMenu script from GitHub..."
curl -sSL "$SCRIPT_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"

# Verify download success
if [[ ! -f "$INSTALL_DIR/$SCRIPT_NAME" ]]; then
    echo "❌ Error: Failed to download sshmenu.sh from GitHub."
    exit 1
fi

# Make it executable
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Detect the current shell
CURRENT_SHELL=$(basename "$SHELL")

# Determine the correct shell profile file
SHELL_CONFIG=""
if [[ $SYSTEM_INSTALL == false ]]; then
    case "$CURRENT_SHELL" in
        bash) SHELL_CONFIG="$HOME/.bashrc" ;;
        zsh)  SHELL_CONFIG="$HOME/.zshrc" ;;
        fish) SHELL_CONFIG="$HOME/.config/fish/config.fish" ;;
    esac
fi

# Check if the install directory is in the PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo "🔧 Adding $INSTALL_DIR to your PATH..."

    # Add to the current shell session
    export PATH="$INSTALL_DIR:$PATH"
    echo "✅ Updated PATH for this session."

    # Add to the correct shell profile for persistence (only for non-root users)
    if [[ -n "$SHELL_CONFIG" ]]; then
        if ! grep -Fxq "export PATH=\"$INSTALL_DIR:\$PATH\"" "$SHELL_CONFIG"; then
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$SHELL_CONFIG"
            echo "✅ PATH added to $SHELL_CONFIG for future sessions."
        else
            echo "✅ PATH is already set in $SHELL_CONFIG."
        fi
    else
        echo "⚠️ No recognized shell profile found. Please manually add this to your shell configuration:"
        echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
    fi
else
    echo "✅ $INSTALL_DIR is already in your PATH."
fi

# Success message
echo "SSHMenu installed successfully! You can now run it using: sshmenu"

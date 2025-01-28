#!/bin/bash

INSTALL_DIR="$HOME/.local/bin"
SYSTEM_INSTALL=false

# Detect if running as root, suggest /usr/local/bin
if [[ $EUID -eq 0 ]]; then
    INSTALL_DIR="/usr/local/bin"
    SYSTEM_INSTALL=true
fi

# Ensure the install directory exists
mkdir -p "$INSTALL_DIR"

# Copy sshmenu.sh to the install location
cp sshmenu.sh "$INSTALL_DIR/sshmenu"

# Make it executable
chmod +x "$INSTALL_DIR/sshmenu"

# Detect the current shell
CURRENT_SHELL=$(basename "$SHELL")

# Determine the correct shell profile file
case "$CURRENT_SHELL" in
    bash)  SHELL_CONFIG="$HOME/.bashrc" ;;
    zsh)   SHELL_CONFIG="$HOME/.zshrc" ;;
    fish)  SHELL_CONFIG="$HOME/.config/fish/config.fish" ;;
    *)     SHELL_CONFIG="" ;;
esac

# Check if the install directory is in the PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo "🔧 Adding $INSTALL_DIR to your PATH..."

    # Add to the current shell session
    export PATH="$INSTALL_DIR:$PATH"
    echo "✅ Updated PATH for this session."

    # Add to the correct shell profile for persistence
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
echo "SSHMenu installed! You can now run it immediately using: sshmenu"

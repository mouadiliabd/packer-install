#!/bin/bash

# Packer Installation Script
# Supports: Linux (amd64/arm64), macOS (amd64/arm64), Windows (WSL/Git Bash)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default variables
PACKER_VERSION="latest"
INSTALL_DIR="/usr/local/bin"
DOWNLOAD_BASE_URL="https://releases.hashicorp.com/packer"

# Function to print colored output
print_message() {
    echo -e "${2}${1}${NC}"
}

# Function to detect OS and architecture
detect_platform() {
    print_message "Detecting system platform..." "${YELLOW}"
    
    case "$(uname -s)" in
        Linux*)     OS="linux";;
        Darwin*)    OS="darwin";;
        CYGWIN*|MINGW*|MSYS*) OS="windows";;
        *)          print_message "Unsupported operating system: $(uname -s)" "${RED}"; exit 1;;
    esac
    
    case "$(uname -m)" in
        x86_64|amd64) ARCH="amd64";;
        aarch64|arm64) ARCH="arm64";;
        *)            print_message "Unsupported architecture: $(uname -m)" "${RED}"; exit 1;;
    esac
    
    print_message "Detected: $OS/$ARCH" "${GREEN}"
}

# Function to get latest Packer version
get_latest_version() {
    if [ "$PACKER_VERSION" = "latest" ]; then
        print_message "Fetching latest Packer version..." "${YELLOW}"
        LATEST_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/packer | grep -o '"current_version":"[^"]*"' | cut -d'"' -f4)
        if [ -z "$LATEST_VERSION" ]; then
            print_message "Failed to fetch latest version. Please check your internet connection." "${RED}"
            exit 1
        fi
        PACKER_VERSION=$LATEST_VERSION
        print_message "Latest version: $PACKER_VERSION" "${GREEN}"
    fi
}

# Function to download and install Packer
install_packer() {
    local filename="packer_${PACKER_VERSION}_${OS}_${ARCH}.zip"
    local download_url="${DOWNLOAD_BASE_URL}/${PACKER_VERSION}/${filename}"
    local temp_dir=$(mktemp -d)
    
    print_message "Downloading Packer ${PACKER_VERSION} for ${OS}/${ARCH}..." "${YELLOW}"
    
    # Download the zip file
    if ! curl -L --fail --progress-bar -o "${temp_dir}/packer.zip" "$download_url"; then
        print_message "Failed to download Packer. Please check version and platform compatibility." "${RED}"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    print_message "Extracting Packer..." "${YELLOW}"
    
    # Extract the zip file
    if ! unzip -q "${temp_dir}/packer.zip" -d "$temp_dir"; then
        print_message "Failed to extract Packer. Please ensure unzip is installed." "${RED}"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Install the binary
    print_message "Installing Packer to ${INSTALL_DIR}..." "${YELLOW}"
    
    # Check if we have write permissions
    if [ ! -w "$INSTALL_DIR" ]; then
        print_message "No write permission to ${INSTALL_DIR}. Using sudo..." "${YELLOW}"
        sudo mv "${temp_dir}/packer" "${INSTALL_DIR}/packer"
    else
        mv "${temp_dir}/packer" "${INSTALL_DIR}/packer"
    fi
    
    # Set executable permissions
    if [ "$OS" != "windows" ]; then
        chmod +x "${INSTALL_DIR}/packer"
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    print_message "Packer ${PACKER_VERSION} installed successfully!" "${GREEN}"
}

# Function to verify installation
verify_installation() {
    print_message "Verifying installation..." "${YELLOW}"
    
    if command -v packer >/dev/null 2>&1; then
        local installed_version=$(packer version | head -n1)
        print_message "✓ Packer is installed: ${installed_version}" "${GREEN}"
        
        # Check if the directory is in PATH
        if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
            print_message "⚠ Warning: ${INSTALL_DIR} might not be in your PATH" "${YELLOW}"
            print_message "  Add this line to your ~/.bashrc or ~/.zshrc:" "${YELLOW}"
            print_message "  export PATH=\"\$PATH:${INSTALL_DIR}\"" "${YELLOW}"
        fi
    else
        print_message "✗ Packer installation verification failed!" "${RED}"
        exit 1
    fi
}

# Function to show help
show_help() {
    cat << EOF
Packer Installation Script

Usage: $0 [OPTIONS]

Options:
    -v, --version VERSION    Install specific Packer version (default: latest)
    -d, --directory DIR      Installation directory (default: /usr/local/bin)
    -h, --help              Show this help message

Examples:
    $0                      # Install latest version
    $0 -v 1.9.1            # Install specific version
    $0 -d ~/bin            # Install to custom directory
    $0 --version 1.8.7     # Install specific version (alternative syntax)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            PACKER_VERSION="$2"
            shift 2
            ;;
        -d|--directory)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_message "Unknown option: $1" "${RED}"
            show_help
            exit 1
            ;;
    esac
done

# Main installation process
main() {
    print_message "=== Packer Installation Script ===" "${GREEN}"
    print_message "Version: ${PACKER_VERSION}" "${YELLOW}"
    print_message "Install Directory: ${INSTALL_DIR}" "${YELLOW}"
    echo
    
    detect_platform
    get_latest_version
    install_packer
    verify_installation
    
    print_message "\nInstallation complete! You can now use 'packer' command." "${GREEN}"
    print_message "Try: packer --version" "${YELLOW}"
}

# Run the main function
main

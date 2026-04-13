# Packer Installation Script

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash Version](https://img.shields.io/badge/bash-4.0%2B-blue)](https://www.gnu.org/software/bash/)
[![Packer](https://img.shields.io/badge/packer-latest-blue)](https://www.packer.io/)

A simple, cross-platform script to install HashiCorp Packer on Linux, macOS, and Windows (WSL/Git Bash).

## 📋 Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Installation](#quick-installation)
- [Detailed Installation](#detailed-installation)
- [Usage Examples](#usage-examples)
- [Manual Installation](#manual-installation)
- [Verification](#verification)
- [Uninstallation](#uninstallation)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## ✨ Features

- **Cross-platform support** - Works on Linux, macOS, and Windows (WSL/Git Bash)
- **Architecture detection** - Automatically detects AMD64 and ARM64 architectures
- **Version management** - Install latest or specific Packer versions
- **Permission handling** - Uses sudo automatically when needed
- **PATH verification** - Checks if installation directory is in your PATH
- **Error handling** - Comprehensive error messages and graceful failure
- **Colored output** - Easy-to-read console output with color coding
- **Zero dependencies** - Only requires standard Unix utilities

## 📋 Prerequisites

Before running the script, ensure you have:

- **Linux/macOS:** `curl` or `wget`, `unzip`
- **Windows:** WSL (Windows Subsystem for Linux) or Git Bash
- **Internet connection** for downloading Packer

### Install Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y curl unzip
```

**RHEL/CentOS/Fedora:**
```bash
sudo yum install -y curl unzip
# or for newer versions
sudo dnf install -y curl unzip
```

**macOS:**
```bash
brew install curl unzip
```

**Windows (WSL):**
```bash
sudo apt-get update && sudo apt-get install -y curl unzip
```

## 🚀 Quick Installation

The fastest way to install Packer:

```bash
# Download and run the script
curl -fsSL https://raw.githubusercontent.com/yourusername/packer-installer/main/install_packer.sh | bash
```

Or using wget:

```bash
wget -qO- https://raw.githubusercontent.com/yourusername/packer-installer/main/install_packer.sh | bash
```

## 📦 Detailed Installation

### Step 1: Download the Script

```bash
# Using curl
curl -O https://raw.githubusercontent.com/yourusername/packer-installer/main/install_packer.sh

# Using wget
wget https://raw.githubusercontent.com/yourusername/packer-installer/main/install_packer.sh
```

### Step 2: Make it Executable

```bash
chmod +x install_packer.sh
```

### Step 3: Run the Script

```bash
# Install latest version (default)
./install_packer.sh

# Install specific version
./install_packer.sh -v 1.9.1

# Install to custom directory
./install_packer.sh -d ~/bin

# View help
./install_packer.sh --help
```

## 🎯 Usage Examples

### Install Latest Version
```bash
$ ./install_packer.sh
=== Packer Installation Script ===
Version: latest
Install Directory: /usr/local/bin

Detecting system platform...
Detected: linux/amd64
Fetching latest Packer version...
Latest version: 1.10.0
Downloading Packer 1.10.0 for linux/amd64...
Installing Packer to /usr/local/bin...
✓ Packer is installed: Packer v1.10.0
Installation complete!
```

### Install Specific Version
```bash
# Install Packer 1.8.7
./install_packer.sh --version 1.8.7

# Alternative syntax
./install_packer.sh -v 1.9.0
```

### Custom Installation Directory
```bash
# Install to user's local bin
./install_packer.sh -d ~/.local/bin

# Install to custom location
./install_packer.sh -d /opt/packer/bin
```

## 🔧 Manual Installation

If you prefer manual installation without the script:

### Linux/macOS
```bash
# Set version and platform
PACKER_VERSION="1.10.0"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')

# Download and install
curl -LO "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_${OS}_${ARCH}.zip"
unzip "packer_${PACKER_VERSION}_${OS}_${ARCH}.zip"
sudo mv packer /usr/local/bin/
rm "packer_${PACKER_VERSION}_${OS}_${ARCH}.zip"
```

### Windows (PowerShell)
```powershell
# PowerShell as Administrator
$env:PACKER_VERSION="1.10.0"
$env:URL="https://releases.hashicorp.com/packer/${env:PACKER_VERSION}/packer_${env:PACKER_VERSION}_windows_amd64.zip"

Invoke-WebRequest -Uri $env:URL -OutFile packer.zip
Expand-Archive -Path packer.zip -DestinationPath C:\tools\packer
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\tools\packer", [EnvironmentVariableTarget]::Machine)
```

## ✅ Verification

After installation, verify Packer is working:

```bash
# Check version
packer --version

# Should output something like: Packer v1.10.0

# Check help
packer --help

# Test a simple build (requires a template file)
packer validate example.pkr.hcl
```

## 🗑️ Uninstallation

To remove Packer:

```bash
# Remove binary
sudo rm /usr/local/bin/packer

# If installed to custom directory
rm /path/to/your/installation/packer

# Remove any Packer directories (optional)
rm -rf ~/.packer.d
```

## 🔍 Troubleshooting

### Common Issues and Solutions

#### "unzip: command not found"
```bash
# Install unzip
# Ubuntu/Debian
sudo apt-get install unzip

# RHEL/CentOS
sudo yum install unzip

# macOS
brew install unzip
```

#### "Permission denied" when installing
```bash
# Either run with sudo
sudo ./install_packer.sh

# Or install to user directory
./install_packer.sh -d ~/.local/bin
```

#### "packer: command not found" after installation
```bash
# Add installation directory to PATH
export PATH=$PATH:/usr/local/bin

# Or add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
source ~/.bashrc
```

#### Connection errors during download
```bash
# Check internet connection
ping -c 3 releases.hashicorp.com

# Try using wget instead
# Or check if firewall is blocking the connection
```

#### ARM64 architecture not recognized
```bash
# Manual download for ARM64
PACKER_VERSION="1.10.0"
curl -LO "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_arm64.zip"
unzip packer_${PACKER_VERSION}_linux_arm64.zip
sudo mv packer /usr/local/bin/
```

## 📚 Additional Resources

- [Official Packer Documentation](https://www.packer.io/docs)
- [Packer GitHub Repository](https://github.com/hashicorp/packer)
- [Packer Downloads](https://releases.hashicorp.com/packer/)
- [Packer Tutorials](https://developer.hashicorp.com/packer/tutorials)

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Test your changes on multiple platforms if possible
- Update documentation for any new features
- Follow existing code style and conventions
- Add comments for complex logic

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

This script is community-maintained and not officially supported by HashiCorp. Always verify downloads from official sources and use at your own risk.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/packer-installer/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/packer-installer/discussions)

## 🙏 Acknowledgments

- [HashiCorp](https://www.hashicorp.com/) for creating Packer
- All contributors and users of this script

---

**Made with ❤️ for the DevOps community**

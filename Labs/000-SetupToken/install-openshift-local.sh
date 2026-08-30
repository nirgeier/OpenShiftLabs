#!/bin/bash

################################################################################
# OpenShift Local Installation Script for Linux
################################################################################
# This script automates the installation and setup of OpenShift Local (CRC)
# on a Linux system. It handles prerequisites, downloads, installation, and
# initial configuration.
#
# Prerequisites:
#   - Linux OS (RHEL, Fedora, CentOS, Ubuntu, etc.)
#   - Minimum 9 GB of free RAM
#   - Minimum 35 GB of free disk space
#   - AMD64/x86_64 architecture
#   - Active internet connection
#
# Usage:
#   chmod +x install-openshift-local.sh
#   ./install-openshift-local.sh
#
# Author: OpenShift Setup Script
# Date: November 2025
################################################################################

set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
CRC_VERSION="2.42.0"  # Update this to the latest version
CRC_DOWNLOAD_URL="https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/${CRC_VERSION}/crc-linux-amd64.tar.xz"
INSTALL_DIR="${HOME}/.crc"
BIN_DIR="${HOME}/.local/bin"

################################################################################
# Helper Functions
################################################################################

# Print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print section headers
print_header() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

################################################################################
# System Checks
################################################################################

check_system_requirements() {
    print_header "Checking System Requirements"
    
    # Check if running on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_error "This script is designed for Linux systems only."
        exit 1
    fi
    print_success "Running on Linux"
    
    # Check architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" ]]; then
        print_error "Unsupported architecture: $ARCH. Required: x86_64"
        exit 1
    fi
    print_success "Architecture: $ARCH"
    
    # Check available RAM (in MB)
    TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
    REQUIRED_RAM=9000
    if [[ $TOTAL_RAM -lt $REQUIRED_RAM ]]; then
        print_warning "Available RAM: ${TOTAL_RAM}MB. Recommended: ${REQUIRED_RAM}MB or more"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "Available RAM: ${TOTAL_RAM}MB"
    fi
    
    # Check available disk space (in GB)
    AVAILABLE_DISK=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
    REQUIRED_DISK=35
    if [[ $AVAILABLE_DISK -lt $REQUIRED_DISK ]]; then
        print_warning "Available disk space: ${AVAILABLE_DISK}GB. Required: ${REQUIRED_DISK}GB"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "Available disk space: ${AVAILABLE_DISK}GB"
    fi
    
    # Check if virtualization is enabled
    if grep -E 'vmx|svm' /proc/cpuinfo > /dev/null 2>&1; then
        print_success "CPU virtualization is enabled"
    else
        print_error "CPU virtualization is NOT enabled. Please enable it in BIOS."
        exit 1
    fi
}

################################################################################
# Install Dependencies
################################################################################

install_dependencies() {
    print_header "Installing Dependencies"
    
    # Detect package manager
    if command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        INSTALL_CMD="sudo dnf install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        INSTALL_CMD="sudo yum install -y"
    elif command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        INSTALL_CMD="sudo apt-get install -y"
        sudo apt-get update
    else
        print_warning "Could not detect package manager. Please install dependencies manually."
        return
    fi
    
    print_info "Detected package manager: $PKG_MANAGER"
    
    # Install required packages
    PACKAGES="libvirt libvirt-daemon-kvm qemu-kvm NetworkManager"
    
    if [[ "$PKG_MANAGER" == "apt-get" ]]; then
        PACKAGES="libvirt-daemon libvirt-clients qemu-kvm network-manager"
    fi
    
    print_info "Installing required packages: $PACKAGES"
    $INSTALL_CMD $PACKAGES || print_warning "Some packages may have failed to install"
    
    # Start and enable libvirtd
    print_info "Starting libvirtd service..."
    sudo systemctl start libvirtd
    sudo systemctl enable libvirtd
    print_success "libvirtd service is running"
    
    # Add current user to libvirt group
    print_info "Adding user to libvirt group..."
    if getent group libvirt > /dev/null 2>&1; then
        sudo usermod -aG libvirt "$USER"
        print_success "User added to libvirt group (re-login required for changes to take effect)"
    fi
}

################################################################################
# Download and Install CRC
################################################################################

download_crc() {
    print_header "Downloading OpenShift Local (CRC)"
    
    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    print_info "Downloading CRC version ${CRC_VERSION}..."
    print_info "Download URL: ${CRC_DOWNLOAD_URL}"
    
    # Download CRC
    if command -v wget &> /dev/null; then
        wget -O crc-linux-amd64.tar.xz "${CRC_DOWNLOAD_URL}" || {
            print_error "Download failed. Please check your internet connection or visit:"
            print_error "https://developers.redhat.com/products/openshift-local/download"
            exit 1
        }
    elif command -v curl &> /dev/null; then
        curl -L -o crc-linux-amd64.tar.xz "${CRC_DOWNLOAD_URL}" || {
            print_error "Download failed. Please check your internet connection or visit:"
            print_error "https://developers.redhat.com/products/openshift-local/download"
            exit 1
        }
    else
        print_error "Neither wget nor curl found. Please install one of them."
        exit 1
    fi
    
    print_success "Download complete"
    
    # Extract archive
    print_info "Extracting archive..."
    tar -xf crc-linux-amd64.tar.xz
    
    # Find the extracted directory
    CRC_EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "crc-linux-*" | head -n 1)
    
    if [[ -z "$CRC_EXTRACTED_DIR" ]]; then
        print_error "Failed to find extracted CRC directory"
        exit 1
    fi
    
    # Create bin directory if it doesn't exist
    mkdir -p "$BIN_DIR"
    
    # Copy binary to bin directory
    print_info "Installing CRC binary to ${BIN_DIR}..."
    cp "${CRC_EXTRACTED_DIR}/crc" "$BIN_DIR/"
    chmod +x "${BIN_DIR}/crc"
    
    # Clean up
    cd - > /dev/null
    rm -rf "$TMP_DIR"
    
    print_success "CRC installed successfully"
}

################################################################################
# Configure PATH
################################################################################

configure_path() {
    print_header "Configuring PATH"
    
    # Detect shell configuration file
    if [[ -f "$HOME/.bashrc" ]]; then
        SHELL_RC="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        SHELL_RC="$HOME/.zshrc"
    else
        SHELL_RC="$HOME/.profile"
    fi
    
    # Check if BIN_DIR is already in PATH
    if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
        print_info "Adding ${BIN_DIR} to PATH in ${SHELL_RC}..."
        echo "" >> "$SHELL_RC"
        echo "# OpenShift Local (CRC) binary path" >> "$SHELL_RC"
        echo "export PATH=\"\$PATH:${BIN_DIR}\"" >> "$SHELL_RC"
        export PATH="$PATH:$BIN_DIR"
        print_success "PATH updated"
    else
        print_info "BIN_DIR already in PATH"
    fi
}

################################################################################
# Setup CRC
################################################################################

setup_crc() {
    print_header "Setting Up OpenShift Local"
    
    # Run crc setup
    print_info "Running 'crc setup' (this may take a few minutes)..."
    "${BIN_DIR}/crc" setup
    
    print_success "CRC setup complete"
}

################################################################################
# Configure CRC
################################################################################

configure_crc() {
    print_header "Configuring OpenShift Local"
    
    # Set memory (default: 9 GB)
    print_info "Setting memory to 9216 MB..."
    "${BIN_DIR}/crc" config set memory 9216
    
    # Set CPUs (default: 4)
    print_info "Setting CPUs to 4..."
    "${BIN_DIR}/crc" config set cpus 4
    
    # Enable monitoring (optional)
    read -p "Enable cluster monitoring? (requires more resources) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "${BIN_DIR}/crc" config set enable-cluster-monitoring true
        print_success "Cluster monitoring enabled"
    else
        "${BIN_DIR}/crc" config set enable-cluster-monitoring false
        print_info "Cluster monitoring disabled"
    fi
    
    # Set consent telemetry
    "${BIN_DIR}/crc" config set consent-telemetry no
    
    print_success "CRC configuration complete"
}

################################################################################
# Start CRC
################################################################################

start_crc() {
    print_header "Starting OpenShift Local Cluster"
    
    # Check if pull secret exists in current directory
    PULL_SECRET=""
    if [[ -f "pull-secret.json" ]]; then
        PULL_SECRET="$(pwd)/pull-secret.json"
        print_info "Found pull secret at: $PULL_SECRET"
    elif [[ -f "$HOME/pull-secret.json" ]]; then
        PULL_SECRET="$HOME/pull-secret.json"
        print_info "Found pull secret at: $PULL_SECRET"
    else
        print_warning "Pull secret not found."
        print_info "Download it from: https://console.redhat.com/openshift/create/local"
        read -p "Enter path to pull-secret.json (or press Enter to skip): " PULL_SECRET_INPUT
        if [[ -n "$PULL_SECRET_INPUT" ]] && [[ -f "$PULL_SECRET_INPUT" ]]; then
            PULL_SECRET="$PULL_SECRET_INPUT"
        fi
    fi
    
    # Start CRC
    if [[ -n "$PULL_SECRET" ]]; then
        print_info "Starting CRC with pull secret (this will take 10-15 minutes)..."
        "${BIN_DIR}/crc" start -p "$PULL_SECRET"
    else
        print_info "Starting CRC (this will take 10-15 minutes)..."
        "${BIN_DIR}/crc" start
    fi
    
    print_success "OpenShift cluster started successfully!"
}

################################################################################
# Display Access Information
################################################################################

display_access_info() {
    print_header "OpenShift Cluster Access Information"
    
    # Get console URL and credentials
    "${BIN_DIR}/crc" console --credentials
    
    echo ""
    print_info "To access the OpenShift console, run:"
    echo "  crc console"
    
    echo ""
    print_info "To login with oc CLI, run:"
    echo "  eval \$(crc oc-env)"
    echo "  oc login -u developer https://api.crc.testing:6443"
    
    echo ""
    print_info "Useful commands:"
    echo "  crc status          - Check cluster status"
    echo "  crc stop            - Stop the cluster"
    echo "  crc start           - Start the cluster"
    echo "  crc delete          - Delete the cluster"
    echo "  crc console         - Open web console"
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    print_header "OpenShift Local Installation Script"
    
    print_info "This script will install and configure OpenShift Local (CRC) on your Linux system."
    echo ""
    
    # Run installation steps
    check_system_requirements
    install_dependencies
    download_crc
    configure_path
    setup_crc
    configure_crc
    
    # Ask if user wants to start the cluster now
    echo ""
    read -p "Do you want to start the OpenShift cluster now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_crc
        display_access_info
    else
        print_info "You can start the cluster later by running: crc start"
    fi
    
    echo ""
    print_success "Installation complete!"
    print_warning "Note: You may need to re-login for group changes to take effect."
    echo ""
}

# Run main function
main "$@"

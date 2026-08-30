#!/bin/bash

################################################################################
# Minishift Installation Script (macOS & Linux)
################################################################################
# This script automates the download, installation, and startup of Minishift,
# a single-node OpenShift 3.x cluster that runs inside a local virtual machine.
#
# NOTE: Minishift is a LEGACY tool. It ships OpenShift 3.11 and is no longer
#       actively developed (last release v1.34.3). For OpenShift 4.x, prefer
#       CRC (install-openshift-local.sh) or MicroShift (install-microshift-mac.sh).
#       This script is provided to mirror the original course, which uses
#       Minishift + VirtualBox.
#
# Prerequisites:
#   - macOS (Intel) or Linux, x86_64 / amd64 architecture
#   - A supported hypervisor (VirtualBox recommended for cross-platform use)
#   - At least 4 GB free RAM (8 GB+ recommended) and 20 GB free disk
#   - Active internet connection
#
# Usage:
#   chmod +x install-minishift.sh
#   ./install-minishift.sh
#
# Override defaults with environment variables, e.g.:
#   MINISHIFT_VM_DRIVER=kvm ./install-minishift.sh
#
# Author: OpenShift Lab Setup
# Date: August 2026
################################################################################

set -euo pipefail

################################################################################
# Configuration
################################################################################
MINISHIFT_VERSION="${MINISHIFT_VERSION:-1.34.3}"
# Hypervisor driver: virtualbox (default), kvm (Linux), hyperkit (macOS), xhyve
MINISHIFT_VM_DRIVER="${MINISHIFT_VM_DRIVER:-virtualbox}"
VM_CPUS="${VM_CPUS:-2}"
VM_MEMORY_MB="${VM_MEMORY_MB:-4096}"
VM_DISK_GB="${VM_DISK_GB:-20}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

################################################################################
# Colors & Helpers
################################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

print_header() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

################################################################################
# Detect Platform
################################################################################
detect_platform() {
    print_header "Detecting Platform"

    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
        print_error "Minishift only provides amd64/x86_64 builds. Detected: $ARCH"
        if [[ "$ARCH" == "arm64" ]]; then
            print_warning "Apple Silicon / ARM is not supported by Minishift."
            print_info "Use CRC (install-openshift-local.sh) or MicroShift (install-microshift-mac.sh) instead."
        fi
        exit 1
    fi

    case "$OSTYPE" in
        darwin*) OS="darwin" ;;
        linux*)  OS="linux" ;;
        *)
            print_error "Unsupported OS: $OSTYPE"
            exit 1
            ;;
    esac

    print_success "OS: $OS, Architecture: $ARCH"
}

################################################################################
# Check Hypervisor
################################################################################
check_hypervisor() {
    print_header "Checking Hypervisor: $MINISHIFT_VM_DRIVER"

    case "$MINISHIFT_VM_DRIVER" in
        virtualbox)
            if command -v VBoxManage &> /dev/null; then
                print_success "VirtualBox is installed ($(VBoxManage --version 2>/dev/null | head -n1))"
            else
                print_error "VirtualBox not found. Install it from https://www.virtualbox.org/wiki/Downloads"
                if [[ "$OS" == "darwin" ]]; then
                    print_info "Or via Homebrew: brew install --cask virtualbox"
                fi
                exit 1
            fi
            ;;
        kvm)
            if command -v virsh &> /dev/null; then
                print_success "KVM/libvirt is available"
                print_info "Ensure docker-machine-driver-kvm is installed and on PATH."
            else
                print_error "KVM/libvirt not found. Install libvirt + docker-machine-driver-kvm."
                exit 1
            fi
            ;;
        hyperkit)
            print_info "Using HyperKit driver. Ensure docker-machine-driver-hyperkit is installed."
            print_info "  brew install hyperkit docker-machine-driver-hyperkit"
            ;;
        *)
            print_warning "Unrecognized driver '$MINISHIFT_VM_DRIVER'. Proceeding, but ensure it is installed."
            ;;
    esac
}

################################################################################
# Download and Install Minishift
################################################################################
install_minishift() {
    print_header "Downloading Minishift v${MINISHIFT_VERSION}"

    if command -v minishift &> /dev/null; then
        print_info "Minishift already installed: $(minishift version | head -n1)"
        return
    fi

    local archive="minishift-${MINISHIFT_VERSION}-${OS}-amd64.tgz"
    local url="https://github.com/minishift/minishift/releases/download/v${MINISHIFT_VERSION}/${archive}"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    print_info "Download URL: $url"
    if command -v curl &> /dev/null; then
        curl -fSL -o "${tmp_dir}/${archive}" "$url" || {
            print_error "Download failed. Check the version or your connection."
            exit 1
        }
    elif command -v wget &> /dev/null; then
        wget -O "${tmp_dir}/${archive}" "$url" || {
            print_error "Download failed. Check the version or your connection."
            exit 1
        }
    else
        print_error "Neither curl nor wget found. Please install one."
        exit 1
    fi
    print_success "Download complete"

    print_info "Extracting archive..."
    tar -xzf "${tmp_dir}/${archive}" -C "$tmp_dir"

    local extracted
    extracted=$(find "$tmp_dir" -maxdepth 1 -type d -name "minishift-*" | head -n1)
    if [[ -z "$extracted" ]]; then
        print_error "Could not find extracted Minishift directory."
        exit 1
    fi

    mkdir -p "$BIN_DIR"
    cp "${extracted}/minishift" "$BIN_DIR/"
    chmod +x "${BIN_DIR}/minishift"
    rm -rf "$tmp_dir"

    print_success "Minishift installed to ${BIN_DIR}/minishift"
}

################################################################################
# Configure PATH
################################################################################
configure_path() {
    print_header "Configuring PATH"

    if [[ -n "${ZSH_VERSION:-}" || -f "$HOME/.zshrc" ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        SHELL_RC="$HOME/.bashrc"
    else
        SHELL_RC="$HOME/.profile"
    fi

    if [[ ":$PATH:" != *":${BIN_DIR}:"* ]]; then
        print_info "Adding ${BIN_DIR} to PATH in ${SHELL_RC}..."
        {
            echo ""
            echo "# Minishift binary path"
            echo "export PATH=\"\$PATH:${BIN_DIR}\""
        } >> "$SHELL_RC"
        export PATH="$PATH:$BIN_DIR"
        print_success "PATH updated (restart your shell or 'source ${SHELL_RC}')"
    else
        print_info "${BIN_DIR} already in PATH"
    fi
}

################################################################################
# Start Minishift
################################################################################
start_minishift() {
    print_header "Starting Minishift Cluster"

    print_info "Driver: ${MINISHIFT_VM_DRIVER} | CPUs: ${VM_CPUS} | Memory: ${VM_MEMORY_MB}MB | Disk: ${VM_DISK_GB}GB"
    print_info "The first start downloads the OpenShift ISO and may take several minutes..."

    "${BIN_DIR}/minishift" start \
        --vm-driver "${MINISHIFT_VM_DRIVER}" \
        --cpus "${VM_CPUS}" \
        --memory "${VM_MEMORY_MB}" \
        --disk-size "${VM_DISK_GB}GB"

    print_success "Minishift cluster is running"
}

################################################################################
# Display Access Information
################################################################################
display_access_info() {
    print_header "Minishift Access Information"

    "${BIN_DIR}/minishift" console --url 2>/dev/null || true

    echo ""
    print_info "Point your shell at Minishift's oc client:"
    echo "  eval \$(minishift oc-env)"
    echo ""
    print_info "Default developer login (web console + CLI):"
    echo "  Username: developer"
    echo "  Password: developer"
    echo ""
    print_info "Log in with the oc CLI:"
    echo "  oc login -u developer -p developer \$(minishift ip):8443"
    echo ""
    print_info "Useful commands:"
    echo "  minishift status     - Show cluster status"
    echo "  minishift console    - Open the web console"
    echo "  minishift stop       - Stop the cluster"
    echo "  minishift start      - Start the cluster"
    echo "  minishift delete     - Delete the VM"
}

################################################################################
# Main
################################################################################
main() {
    print_header "Minishift Installation Script"
    print_warning "Minishift is legacy (OpenShift 3.11). For OpenShift 4.x use CRC or MicroShift."
    echo ""

    detect_platform
    check_hypervisor
    install_minishift
    configure_path

    echo ""
    read -p "Start the Minishift cluster now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        start_minishift
        display_access_info
    else
        print_info "Skipping cluster start."
        print_info "Start it later with: minishift start --vm-driver ${MINISHIFT_VM_DRIVER}"
    fi

    print_success "Done."
}

main "$@"

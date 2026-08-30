#!/bin/bash

################################################################################
# MicroShift Installation Script for macOS
################################################################################
# This script installs and runs a local single-node cluster on macOS using
# Red Hat OpenShift Local (CRC), which bundles both OpenShift and MicroShift.
#
# On macOS the maintained way to run MicroShift is via CRC's 'microshift'
# preset. (The community Lima + copr RPM path is abandoned: the newest copr
# build is MicroShift 4.8.0 from 2022 with no matching CRI-O.) CRC runs
# natively on Apple Silicon and Intel and manages the VM for you.
#
# Prerequisites:
#   - macOS (Intel or Apple Silicon)
#   - Homebrew (https://brew.sh)
#   - openshift preset: ~4 vCPUs / 10.5 GB RAM;  microshift preset: ~2 vCPU / 4 GB
#   - ~35 GB free disk space
#   - An OpenShift pull secret (pull-secret.txt at the repo root, or set
#     PULL_SECRET_FILE). Download one from:
#     https://console.redhat.com/openshift/install/pull-secret
#
# Presets (set via CRC_PRESET):
#   microshift  MicroShift - headless, oc/kubectl only, NO web console  [default]
#   openshift   full OpenShift - includes the web console GUI
#
# What it does:
#   1. Installs CRC and the oc client (via Homebrew) if not present
#   2. Configures CRC (preset, CPUs, memory, pull secret)
#   3. Runs 'crc setup' and 'crc start'
#   4. Prints access info (and the console URL for the openshift preset)
#
# Usage:
#   chmod +x install-microshift-mac.sh
#   ./install-microshift-mac.sh                        # microshift preset
#   CRC_PRESET=openshift ./install-microshift-mac.sh   # web console GUI
#
# Author: OpenShift Lab Setup
# Date: July 2026
################################################################################

set -euo pipefail

################################################################################
# Configuration
################################################################################
# Which cluster flavor CRC should run: 'microshift' (headless) or 'openshift' (GUI).
CRC_PRESET="${CRC_PRESET:-microshift}"
CRC_CPUS="${CRC_CPUS:-4}"
CRC_MEMORY_MB="${CRC_MEMORY_MB:-10240}"
CRC_DISK_GB="${CRC_DISK_GB:-40}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# OpenShift pull secret used by CRC to pull the cluster's container images.
# Defaults to the pull-secret.txt committed at the repo root.
PULL_SECRET_FILE="${PULL_SECRET_FILE:-${SCRIPT_DIR}/../../pull-secret.txt}"

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
# Prerequisite Checks
################################################################################
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is designed for macOS only."
        print_info "For Linux, use the existing install-openshift-local.sh instead."
        exit 1
    fi
    print_success "Running on macOS"

    # Check architecture
    ARCH=$(uname -m)
    print_info "Architecture: $ARCH"

    # Check if Rosetta 2 is needed (Apple Silicon but forcing x86_64)
    if [[ "$ARCH" == "arm64" ]]; then
        if ! /usr/bin/pgrep -q oahd 2>/dev/null; then
            print_warning "Rosetta 2 may be needed for some x86_64 containers."
            print_info "Install it with: softwareupdate --install-rosetta --agree-to-license"
        else
            print_success "Rosetta 2 is installed"
        fi
    fi

    # Check Homebrew
    if ! command -v brew &> /dev/null; then
        print_warning "Homebrew is required. Installing now..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    print_success "Homebrew is installed"

    # Check / install CRC (OpenShift Local)
    if ! command -v crc &> /dev/null; then
        print_info "Installing CRC (OpenShift Local) via Homebrew..."
        brew install crc
    fi
    print_success "CRC is installed"

    # Check / install the oc client
    if ! command -v oc &> /dev/null; then
        print_info "Installing openshift-cli (oc) via Homebrew..."
        brew install openshift-cli
    fi
    print_success "oc client is installed"

    # Check pull secret (required by CRC to pull cluster images)
    if [[ ! -f "$PULL_SECRET_FILE" ]]; then
        print_error "Pull secret not found at: $PULL_SECRET_FILE"
        print_info "Download one from https://console.redhat.com/openshift/install/pull-secret"
        print_info "then save it there or set PULL_SECRET_FILE=/path/to/pull-secret.txt"
        exit 1
    fi
    if ! /usr/bin/python3 -c "import json,sys; json.load(open(sys.argv[1]))['auths']" "$PULL_SECRET_FILE" 2>/dev/null; then
        print_error "Pull secret at $PULL_SECRET_FILE is not a valid JSON pull secret (missing 'auths')."
        exit 1
    fi
    print_success "Pull secret found: $PULL_SECRET_FILE"
}

################################################################################
# Configure CRC
################################################################################
configure_crc() {
    print_header "Configuring CRC (preset: ${CRC_PRESET})"

    if [[ "$CRC_PRESET" != "microshift" && "$CRC_PRESET" != "openshift" ]]; then
        print_error "Invalid CRC_PRESET '${CRC_PRESET}'. Use 'microshift' or 'openshift'."
        exit 1
    fi

    crc config set preset "$CRC_PRESET"
    crc config set cpus "$CRC_CPUS"
    crc config set memory "$CRC_MEMORY_MB"
    crc config set disk-size "$CRC_DISK_GB"
    crc config set pull-secret-file "$PULL_SECRET_FILE"
    crc config set consent-telemetry no > /dev/null 2>&1 || true

    print_success "CRC configured (preset=${CRC_PRESET}, cpus=${CRC_CPUS}, memory=${CRC_MEMORY_MB}MB)"
}

################################################################################
# Prepare the host (one-time)
################################################################################
run_crc_setup() {
    print_header "Preparing the host (crc setup)"

    print_info "This is a one-time step and may prompt for your macOS password..."
    crc setup

    print_success "Host preparation complete"
}

################################################################################
# Start the cluster
################################################################################
start_cluster() {
    print_header "Starting the ${CRC_PRESET} cluster"

    print_info "First start can take 10-15 minutes while images are pulled..."
    crc start --pull-secret-file "$PULL_SECRET_FILE"

    print_success "Cluster started"
}

################################################################################
# Display Access Information
################################################################################
display_access_info() {
    print_header "Cluster Access Information"

    # Make 'oc' available in this shell for the status checks below.
    eval "$(crc oc-env)" 2>/dev/null || true

    echo ""
    echo "  Add oc to your shell:"
    echo "    eval \$(crc oc-env)"
    echo ""
    echo "  Verify the cluster:"
    echo "    oc get nodes"
    echo "    oc get pods -A"
    echo ""

    if [[ "$CRC_PRESET" == "openshift" ]]; then
        echo "  Web console (GUI):"
        echo "    crc console                     # open the web console in your browser"
        echo "    crc console --credentials       # show kubeadmin / developer logins"
        echo "    URL: https://console-openshift-console.apps-crc.testing"
    else
        echo "  NOTE: the 'microshift' preset is headless - there is NO web console."
        echo "        For a GUI, re-run with:  CRC_PRESET=openshift $0"
    fi
    echo ""
    echo "  Manage the cluster:"
    echo "    crc status      # cluster status"
    echo "    crc stop        # stop the cluster"
    echo "    crc start       # start the cluster"
    echo "    crc delete      # delete the cluster"
    echo ""

    if command -v oc &> /dev/null; then
        print_info "Cluster nodes:"
        oc get nodes 2>/dev/null || print_warning "Cluster not reachable yet; it may still be starting."
    fi
}

################################################################################
# Main
################################################################################
main() {
    print_header "MicroShift / OpenShift on macOS (via CRC)"

    print_info "Preset: ${CRC_PRESET}  (set CRC_PRESET=openshift for the web console GUI)"
    echo ""

    check_prerequisites
    configure_crc
    run_crc_setup
    start_cluster
    display_access_info

    echo ""
    print_success "Done - the '${CRC_PRESET}' cluster is up."
    echo ""
    print_info "To start using your cluster, run:"
    echo "  eval \$(crc oc-env)"
    echo "  oc get nodes"
}

main "$@"

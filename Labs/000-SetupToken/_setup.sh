#!/bin/bash
# Setup script for OpenShift Labs
# This script helps set up your OpenShift environment

set -euo pipefail

# Get the root folder of our demo folder
ROOT_FOLDER=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

echo "OpenShift Labs Setup"
echo "===================="
echo ""
echo "Choose setup method:"
echo "1) Full automated installation (install-openshift-local.sh)"
echo "2) Quick start (if CRC is already installed)"
echo "3) Manual - follow the README instructions"
echo ""
read -p "Enter choice [1-3]: " choice

case $choice in
  1)
    echo "Running full installation..."
    bash "$ROOT_FOLDER/Labs/000-SetupToken/install-openshift-local.sh"
    ;;
  2)
    echo "Running quick start..."
    bash "$ROOT_FOLDER/Labs/000-SetupToken/_quick-start.sh"
    ;;
  3)
    echo "Open the README for manual instructions:"
    echo "  $ROOT_FOLDER/Labs/000-SetupToken/README.md"
    ;;
  *)
    echo "Invalid choice"
    exit 1
    ;;
esac

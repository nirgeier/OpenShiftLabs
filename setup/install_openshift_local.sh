#!/bin/bash

# Script to install OpenShift Local (CRC) on macOS
# This script uses Homebrew to install necessary components.

set -e

echo "Checking prerequisites..."

# Check for Homebrew
if ! command -v brew &>/dev/null; then
  echo "Error: Homebrew is not installed."
  echo "Please install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  exit 1
fi

echo "Installing OpenShift Local (crc) and OpenShift CLI (oc)..."

# Install OpenShift CLI
if ! command -v oc &>/dev/null; then
  echo "Installing OpenShift CLI..."
  brew install openshift-cli
else
  echo "OpenShift CLI (oc) is already installed."
fi

# Install CRC
if ! command -v crc &>/dev/null; then
  echo "Installing CRC..."
  brew install crc
else
  echo "CRC is already installed."
fi

echo "Installation complete."
echo "----------------------------------------------------------------"
echo "To set up and start your local OpenShift cluster, follow these steps:"
echo ""
echo "1. Run setup:"
echo "   crc setup"
echo ""
echo "2. Start the cluster (requires Pull Secret from https://console.redhat.com/openshift/create/local):"
echo "   crc start"
echo ""
echo "3. Configure your shell environment for 'oc':"
echo "   eval \$(crc oc-env)"
echo ""
echo "4. Login as kubeadmin:"
echo "   console credentials will be printed after 'crc start' completes."
echo "----------------------------------------------------------------"

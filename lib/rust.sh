#!/usr/bin/env bash
# lib/rust.sh
# Rust-specific functions for the buildpack

# Determine the Rust version to use
determine_rust_version() {
  local build_dir=$1
  local env_dir=$2
  local rust_version="stable"
  
  # Check for environment variable override
  if [ -n "$RUST_VERSION" ]; then
    rust_version="$RUST_VERSION"
  # Check for rust-toolchain.toml file
  elif [ -f "$build_dir/rust-toolchain.toml" ]; then
    rust_version=$(grep "channel\s*=\s*" "$build_dir/rust-toolchain.toml" | sed 's/channel\s*=\s*"\(.*\)"/\1/')
  # Check for rust-toolchain file
  elif [ -f "$build_dir/rust-toolchain" ]; then
    rust_version=$(cat "$build_dir/rust-toolchain")
  fi
  
  echo "$rust_version"
}

# Install Rust toolchain
install_rust_toolchain() {
  local build_dir=$1
  local rust_version=$2
  
  # Create directories
  mkdir -p "$build_dir/.cargo"
  mkdir -p "$build_dir/.rustup"
  
  # Set up environment
  export CARGO_HOME="$build_dir/.cargo"
  export RUSTUP_HOME="$build_dir/.rustup"
  
  # Download rustup
  curl --retry 3 --silent --show-error --fail --location https://sh.rustup.rs -o rustup-init.sh
  chmod +x rustup-init.sh
  
  # Install the Rust toolchain
  ./rustup-init.sh -y --no-modify-path --default-toolchain "$rust_version" 2>&1 | indent
  rm rustup-init.sh
  
  # Add Rust binaries to PATH
  export PATH="$CARGO_HOME/bin:$PATH"
  
  # Verify installation
  rustc --version 2>&1 | indent
  cargo --version 2>&1 | indent
}
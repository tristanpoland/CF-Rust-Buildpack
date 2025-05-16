#!/usr/bin/env bash
# .profile.d/rust.sh - Set Rust environment variables at runtime

# Add Rust bin directory to PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Enable backtraces for easier debugging
export RUST_BACKTRACE=1

# Set other useful Rust environment variables
export RUST_LOG=${RUST_LOG:-info}

# Set PORT from CF_INSTANCE_PORT if available
if [ -z "$PORT" ] && [ -n "$CF_INSTANCE_PORT" ]; then
  export PORT="$CF_INSTANCE_PORT"
fi
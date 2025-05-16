#!/usr/bin/env bash
# lib/utils.sh - Utility functions for Rust buildpack

set -e

# Output with indentation
indent() {
  sed -u 's/^/       /'
}

# Log an error and exit
error() {
  echo " !     $*" >&2
  exit 1
}

# Log a warning
warning() {
  echo " !     $*" >&2
}

# Load environment variables from ENV_DIR
load_env_vars() {
  local env_dir=$1
  
  if [ -d "$env_dir" ]; then
    echo "-----> Loading environment variables"
    
    for env_file in "$env_dir"/*; do
      if [ -f "$env_file" ]; then
        var_name=$(basename "$env_file")
        # Skip internal CF variables
        if [[ "$var_name" != "VCAP_"* ]] && [[ "$var_name" != "CF_"* ]]; then
          var_value=$(cat "$env_file")
          export "$var_name=$var_value"
          
          # Log important variables
          if [[ "$var_name" == "RUST_"* ]] || [[ "$var_name" == "CARGO_"* ]]; then
            echo "       $var_name: $var_value"
          fi
        fi
      fi
    done
  fi
  
  # Set default variables if not specified
  export RUST_BACKTRACE=${RUST_BACKTRACE:-1}
  export CARGO_NET_RETRY=${CARGO_NET_RETRY:-5}
  export CARGO_HTTP_TIMEOUT=${CARGO_HTTP_TIMEOUT:-60}
}

# Auto-detect Rust version using multiple methods
detect_rust_version() {
  local build_dir=$1
  local rust_version="stable"
  
  # Method 1: Check environment variable (highest priority)
  if [ -n "$RUST_VERSION" ]; then
    rust_version="$RUST_VERSION"
    echo "       Using Rust version from RUST_VERSION environment variable: $rust_version"
  
  # Method 2: Check rust-toolchain.toml
  elif [ -f "$build_dir/rust-toolchain.toml" ]; then
    local channel=$(grep -m 1 'channel\s*=' "$build_dir/rust-toolchain.toml" | sed -E 's/channel\s*=\s*"([^"]*)"/\1/')
    if [ -n "$channel" ]; then
      rust_version="$channel"
      echo "       Detected Rust version from rust-toolchain.toml: $rust_version"
    fi
  
  # Method 3: Check rust-toolchain file
  elif [ -f "$build_dir/rust-toolchain" ]; then
    local toolchain_version=$(cat "$build_dir/rust-toolchain" | tr -d '[:space:]')
    if [ -n "$toolchain_version" ]; then
      rust_version="$toolchain_version"
      echo "       Detected Rust version from rust-toolchain file: $rust_version"
    fi
  
  # Method 4: Parse from Cargo.toml
  elif [ -f "$build_dir/Cargo.toml" ]; then
    # Some projects specify rust-version in Cargo.toml
    local cargo_rust_version=$(grep -m 1 'rust-version\s*=' "$build_dir/Cargo.toml" | sed -E 's/rust-version\s*=\s*"([^"]*)"/\1/')
    if [ -n "$cargo_rust_version" ]; then
      rust_version="$cargo_rust_version"
      echo "       Detected Rust version from Cargo.toml: $rust_version"
    fi
  fi
  
  echo "$rust_version"
}

# Check if a cached toolchain exists and is the right version
has_cached_toolchain() {
  local cache_dir=$1
  local rust_version=$2
  
  [ -d "$cache_dir/.cargo" ] && [ -d "$cache_dir/.rustup" ] && \
  [ -f "$cache_dir/.rust-version" ] && [ "$(cat "$cache_dir/.rust-version")" = "$rust_version" ]
}

# Restore cached toolchain
restore_cached_toolchain() {
  local cache_dir=$1
  local build_dir=$2
  
  cp -R "$cache_dir/.cargo" "$build_dir/.cargo"
  cp -R "$cache_dir/.rustup" "$build_dir/.rustup"
}

# Install Rust toolchain
install_rust_toolchain() {
  local build_dir=$1
  local rust_version=$2
  
  echo "       Downloading rustup installer"
  
  curl --retry 3 --silent --show-error --fail --max-time 60 --location \
    https://sh.rustup.rs -o "$build_dir/rustup-init.sh" || error "Failed to download rustup"
  
  chmod +x "$build_dir/rustup-init.sh"
  
  echo "       Installing Rust $rust_version"
  
  # Install Rust silently
  "$build_dir/rustup-init.sh" -y --no-modify-path --profile minimal --default-toolchain "$rust_version" 2>&1 | indent
  rm "$build_dir/rustup-init.sh"
  
  # Verify installation
  if [ ! -f "$build_dir/.cargo/bin/rustc" ]; then
    error "Rust installation failed: rustc not found"
  fi
  
  echo "       Installed Rust version: $("$build_dir/.cargo/bin/rustc" --version)"
}

# Cache the toolchain
cache_toolchain() {
  local build_dir=$1
  local cache_dir=$2
  local rust_version=$3
  
  echo "       Caching Rust toolchain for future builds"
  
  rm -rf "$cache_dir/.cargo" "$cache_dir/.rustup"
  cp -R "$build_dir/.cargo" "$cache_dir/.cargo"
  cp -R "$build_dir/.rustup" "$cache_dir/.rustup"
  echo "$rust_version" > "$cache_dir/.rust-version"
}

# Restore cached dependencies
restore_cached_dependencies() {
  local build_dir=$1
  local cache_dir=$2
  
  if [ -d "$cache_dir/cargo-registry" ]; then
    echo "       Restoring cargo registry from cache"
    mkdir -p "$build_dir/.cargo"
    cp -R "$cache_dir/cargo-registry" "$build_dir/.cargo/registry"
  fi
  
  if [ -d "$cache_dir/cargo-git" ]; then
    echo "       Restoring cargo git cache"
    mkdir -p "$build_dir/.cargo"
    cp -R "$cache_dir/cargo-git" "$build_dir/.cargo/git"
  fi
  
  if [ -d "$cache_dir/target-deps" ]; then
    echo "       Restoring cargo target dependencies"
    mkdir -p "$build_dir/target/release"
    mkdir -p "$build_dir/target/debug"
    
    if [ -d "$cache_dir/target-deps/release" ]; then
      cp -R "$cache_dir/target-deps/release" "$build_dir/target/release/deps"
    fi
    
    if [ -d "$cache_dir/target-deps/debug" ]; then
      cp -R "$cache_dir/target-deps/debug" "$build_dir/target/debug/deps"
    fi
  fi
}

# Cache dependencies for future builds
cache_dependencies() {
  local build_dir=$1
  local cache_dir=$2
  
  if [ -d "$build_dir/.cargo/registry" ]; then
    echo "       Caching cargo registry"
    mkdir -p "$cache_dir"
    rm -rf "$cache_dir/cargo-registry"
    cp -R "$build_dir/.cargo/registry" "$cache_dir/cargo-registry"
  fi
  
  if [ -d "$build_dir/.cargo/git" ]; then
    echo "       Caching cargo git"
    mkdir -p "$cache_dir"
    rm -rf "$cache_dir/cargo-git"
    cp -R "$build_dir/.cargo/git" "$cache_dir/cargo-git"
  fi
  
  if [ -d "$build_dir/target" ]; then
    echo "       Caching cargo target dependencies"
    mkdir -p "$cache_dir/target-deps/release"
    mkdir -p "$cache_dir/target-deps/debug"
    
    # Cache only the deps directory, not the entire target
    if [ -d "$build_dir/target/release/deps" ]; then
      rm -rf "$cache_dir/target-deps/release"
      mkdir -p "$cache_dir/target-deps/release"
      cp -R "$build_dir/target/release/deps" "$cache_dir/target-deps/release"
    fi
    
    if [ -d "$build_dir/target/debug/deps" ]; then
      rm -rf "$cache_dir/target-deps/debug"
      mkdir -p "$cache_dir/target-deps/debug"
      cp -R "$build_dir/target/debug/deps" "$cache_dir/target-deps/debug"
    fi
  fi
}

# Get package name from Cargo.toml
get_package_name() {
  local build_dir=$1
  
  if [ -f "$build_dir/Cargo.toml" ]; then
    local pkg_name=$(grep -m 1 '^\s*name\s*=' "$build_dir/Cargo.toml" | sed -E 's/\s*name\s*=\s*"([^"]*)".*/\1/')
    if [ -n "$pkg_name" ]; then
      echo "$pkg_name"
      return 0
    fi
  fi
  
  # Fallback to directory name if package name can't be determined
  basename "$build_dir"
}

# Get build options for cargo
get_build_options() {
  local build_dir=$1
  local env_dir=$2
  local build_opts="--release"
  
  # Check for custom CARGO_BUILD_FLAGS
  if [ -n "$CARGO_BUILD_FLAGS" ]; then
    build_opts="$CARGO_BUILD_FLAGS"
  fi
  
  # Check for custom cargo features
  if [ -n "$CARGO_FEATURES" ]; then
    build_opts="$build_opts --features $CARGO_FEATURES"
  fi
  
  # Check for specified target
  if [ -n "$CARGO_TARGET" ]; then
    build_opts="$build_opts --target $CARGO_TARGET"
  fi
  
  # Parse rust.toml if it exists
  if [ -f "$build_dir/rust.toml" ]; then
    # Only try to parse if the file has [build] section
    if grep -q '^\[build\]' "$build_dir/rust.toml"; then
      # Add features from rust.toml if not already set
      if [ -z "$CARGO_FEATURES" ] && grep -q '^\s*features\s*=' "$build_dir/rust.toml"; then
        local features=$(grep -m 1 '^\s*features\s*=' "$build_dir/rust.toml" | sed -E 's/\s*features\s*=\s*\[([^]]*)\].*/\1/')
        features=$(echo "$features" | sed -E 's/"//g' | sed -E 's/,/ /g')
        if [ -n "$features" ]; then
          build_opts="$build_opts --features $features"
        fi
      fi
      
      # Add target from rust.toml if not already set
      if [ -z "$CARGO_TARGET" ] && grep -q '^\s*target\s*=' "$build_dir/rust.toml"; then
        local target=$(grep -m 1 '^\s*target\s*=' "$build_dir/rust.toml" | sed -E 's/\s*target\s*=\s*"([^"]*)".*/\1/')
        if [ -n "$target" ]; then
          build_opts="$build_opts --target $target"
        fi
      fi
    fi
  fi
  
  # If using debug mode, adjust options
  if [ "$CARGO_DEBUG" = "true" ] || [ "$RUST_DEBUG" = "true" ]; then
    # Replace --release with --debug or remove it
    build_opts=$(echo "$build_opts" | sed 's/--release//')
  fi
  
  echo "$build_opts"
}

# Analyze build failures to provide useful debugging information
analyze_build_failure() {
  local build_output=$1
  
  echo "Build failed. Here's some troubleshooting information:"
  
  # Check for common errors
  if grep -q "linker .* not found" "$build_output"; then
    echo "Error: Linker not found. This may be due to a missing system dependency."
    echo "Try specifying a different linker or using a different target."
  elif grep -q "could not find .* in" "$build_output"; then
    echo "Error: Missing dependency. Make sure your Cargo.toml correctly specifies all required dependencies."
  elif grep -q "requires rustc" "$build_output"; then
    echo "Error: Incompatible Rust version. Try specifying a different Rust version with the RUST_VERSION env var."
  elif grep -q "memory allocator" "$build_output" || grep -q "out of memory" "$build_output"; then
    echo "Error: Out of memory. Try setting CF_STAGING_MEMORY to a higher value."
  elif grep -q "network failure" "$build_output" || grep -q "failed to download" "$build_output"; then
    echo "Error: Network issues. Consider retrying the build or checking your network settings."
  fi
  
  # Display the last few lines of the build output for more context
  echo "Last few lines of build output:"
  tail -n 20 "$build_output" | indent
  
  # Clean up
  rm -f "$build_output"
}
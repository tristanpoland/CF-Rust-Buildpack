#!/usr/bin/env bash
# lib/cache.sh
# Caching functions for the buildpack

# Check if a cached toolchain exists
has_cached_toolchain() {
  local cache_dir=$1
  local rust_version=$2
  
  [ -d "$cache_dir/.cargo" ] && [ -d "$cache_dir/.rustup" ] && \
  [ -f "$cache_dir/.rust-version" ] && [ "$(cat "$cache_dir/.rust-version")" = "$rust_version" ]
}

# Cache the Rust toolchain
cache_toolchain() {
  local build_dir=$1
  local cache_dir=$2
  local rust_version=$3
  
  echo "-----> Caching Rust toolchain"
  mkdir -p "$cache_dir"
  
  # Remove old cache if it exists
  rm -rf "$cache_dir/.cargo" "$cache_dir/.rustup"
  
  # Copy toolchain to cache
  cp -R "$build_dir/.cargo" "$cache_dir/.cargo"
  cp -R "$build_dir/.rustup" "$cache_dir/.rustup"
  
  # Store rust version
  echo "$rust_version" > "$cache_dir/.rust-version"
}

# Restore cached toolchain
restore_cached_toolchain() {
  local cache_dir=$1
  local build_dir=$2
  
  # Copy cached toolchain to build directory
  cp -R "$cache_dir/.cargo" "$build_dir/.cargo"
  cp -R "$cache_dir/.rustup" "$build_dir/.rustup"
}

# Cache dependencies
cache_dependencies() {
  local build_dir=$1
  local cache_dir=$2
  
  mkdir -p "$cache_dir/target"
  
  # Cache Cargo registry
  if [ -d "$build_dir/.cargo/registry" ]; then
    rm -rf "$cache_dir/.cargo/registry"
    cp -R "$build_dir/.cargo/registry" "$cache_dir/.cargo/registry"
  fi
  
  # Cache Cargo git
  if [ -d "$build_dir/.cargo/git" ]; then
    rm -rf "$cache_dir/.cargo/git"
    cp -R "$build_dir/.cargo/git" "$cache_dir/.cargo/git"
  fi
  
  # Cache target directory (just deps and incremental)
  if [ -d "$build_dir/target" ]; then
    # Only cache dependencies, not the final binaries
    if [ -d "$build_dir/target/release/deps" ]; then
      mkdir -p "$cache_dir/target/release"
      rm -rf "$cache_dir/target/release/deps"
      cp -R "$build_dir/target/release/deps" "$cache_dir/target/release/deps"
    fi
    
    if [ -d "$build_dir/target/release/incremental" ]; then
      mkdir -p "$cache_dir/target/release"
      rm -rf "$cache_dir/target/release/incremental"
      cp -R "$build_dir/target/release/incremental" "$cache_dir/target/release/incremental"
    fi
    
    if [ -d "$build_dir/target/debug/deps" ]; then
      mkdir -p "$cache_dir/target/debug"
      rm -rf "$cache_dir/target/debug/deps"
      cp -R "$build_dir/target/debug/deps" "$cache_dir/target/debug/deps"
    fi
    
    if [ -d "$build_dir/target/debug/incremental" ]; then
      mkdir -p "$cache_dir/target/debug"
      rm -rf "$cache_dir/target/debug/incremental"
      cp -R "$build_dir/target/debug/incremental" "$cache_dir/target/debug/incremental"
    fi
  fi
}

# Restore cached dependencies
restore_cache() {
  local build_dir=$1
  local cache_dir=$2
  
  # Restore Cargo registry and git
  if [ -d "$cache_dir/.cargo/registry" ]; then
    mkdir -p "$build_dir/.cargo"
    cp -R "$cache_dir/.cargo/registry" "$build_dir/.cargo/registry"
  fi
  
  if [ -d "$cache_dir/.cargo/git" ]; then
    mkdir -p "$build_dir/.cargo"
    cp -R "$cache_dir/.cargo/git" "$build_dir/.cargo/git"
  fi
  
  # Restore target deps and incremental
  if [ -d "$cache_dir/target/release/deps" ]; then
    mkdir -p "$build_dir/target/release"
    cp -R "$cache_dir/target/release/deps" "$build_dir/target/release/deps"
  fi
  
  if [ -d "$cache_dir/target/release/incremental" ]; then
    mkdir -p "$build_dir/target/release"
    cp -R "$cache_dir/target/release/incremental" "$build_dir/target/release/incremental"
  fi
  
  if [ -d "$cache_dir/target/debug/deps" ]; then
    mkdir -p "$build_dir/target/debug"
    cp -R "$cache_dir/target/debug/deps" "$build_dir/target/debug/deps"
  fi
  
  if [ -d "$cache_dir/target/debug/incremental" ]; then
    mkdir -p "$build_dir/target/debug"
    cp -R "$cache_dir/target/debug/incremental" "$build_dir/target/debug/incremental"
  fi
}
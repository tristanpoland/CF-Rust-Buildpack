# Rust Buildpack for Cloud Foundry

A production-ready Cloud Foundry buildpack for compiling and deploying Rust applications.

## Features

* **Automatic Rust Detection**: Identifies Rust projects via `Cargo.toml`, `rust-toolchain` files, or source files
* **Intelligent Rust Version Management**:
  * Auto-detects Rust version from multiple sources
  * Supports specific version pinning via environment variables or toolchain files
  * Works with stable, beta, or nightly channels
* **Optimized Caching**:
  * Caches Rust toolchain for faster subsequent builds
  * Aggressively caches dependencies from Cargo registry and git sources
  * Preserves compilation artifacts between builds
* **Advanced Build Configuration**:
  * Custom features via `CARGO_FEATURES` or `rust.toml`
  * Support for cross-compilation via target specification
  * Custom build flags for optimization
* **Intelligent Binary Detection**:
  * Automatically finds the right executable to run
  * Supports both Procfile and auto-detection methods
  * Fallback mechanisms to help ensure your app starts

## Quick Start

### Deploying a Rust App

For most Rust applications, deployment is as simple as:

```Shell
cf push my-app -b https://github.com/tristanpoland/CF-Rust-Buildpack
```

The buildpack will automatically detect your Rust application, compile it, and run it.

### Specifying a Rust Version

The buildpack auto-detects Rust versions in this priority order:

1. `RUST_VERSION` environment variable
2. `rust-toolchain.toml` file
3. `rust-toolchain` file
4. `rust-version` field in `Cargo.toml`

If none of these are found, the latest stable Rust version is used.

Examples:

#### Via environment variable:

```Shell
cf set-env my-app RUST_VERSION 1.75.0
cf restage my-app
```

#### Via rust-toolchain.toml:

```TOML
[toolchain]
channel = "1.75.0"
components = ["rustfmt", "clippy"]
```

#### Via rust-toolchain:

```
1.75.0
```

#### Via Cargo.toml:

```TOML
[package]
name = "my-app"
version = "0.1.0"
rust-version = "1.75.0"
```

## Configuration Options

### Environment Variables

| Variable             | Description                               | Default     |
| -------------------- | ----------------------------------------- | ----------- |
| `RUST_VERSION`       | Rust version to install                   | `stable`    |
| `CARGO_FEATURES`     | Features to enable when building          | None        |
| `CARGO_BUILD_FLAGS`  | Custom flags for `cargo build`            | `--release` |
| `CARGO_TARGET`       | Target triple for cross-compilation       | None        |
| `RUST_BACKTRACE`     | Enable backtraces                         | `1`         |
| `RUST_LOG`           | Log level for Rust applications           | `info`      |
| `CARGO_DEBUG`        | Build in debug mode instead of release    | `false`     |
| `CARGO_NET_RETRY`    | Number of times to retry network requests | `5`         |
| `CARGO_HTTP_TIMEOUT` | Timeout for HTTP requests in seconds      | `60`        |

### Using a Custom Build Configuration

Create a `rust.toml` file in your project root:

```TOML
[build]
# Enable specific features
features = ["cf", "production"]

# Use a specific target (for cross-compilation)
target = "x86_64-unknown-linux-musl"

# Other build options
release = true
```

### Application Launch Configuration

#### Using a Procfile (recommended)

Create a `Procfile` in your project root:

```
web: ./target/release/my-app
```

#### Auto-detection

If no Procfile is present, the buildpack will:

1. Look for a binary in `target/release/` matching your package name
2. Search for any executable in `target/release/`
3. Fall back to `target/debug/` if no release binary is found
4. Use `cargo run --release` as a last resort

## Examples

### Simple Web Server

```Rust
// src/main.rs
use std::env;
use std::net::SocketAddr;

fn main() {
    // Cloud Foundry sets the PORT env variable
    let port = env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("0.0.0.0:{}", port);
    
    println!("Starting server on {}", addr);
    
    // Your server implementation here
}
```

### Using Specific Features in Cloud Foundry

```TOML
# Cargo.toml
[package]
name = "my-app"
version = "0.1.0"

[features]
default = []
cf = []  # Feature for Cloud Foundry specific code

[dependencies]
tokio = { version = "1", features = ["full"] }
axum = "0.7"
```

Enable the `cf` feature for Cloud Foundry deployments:

```Shell
cf set-env my-app CARGO_FEATURES "cf"
cf restage my-app
```

### Cross-compilation Example

For a statically linked binary using musl:

```Shell
cf set-env my-app CARGO_TARGET "x86_64-unknown-linux-musl"
cf set-env my-app RUSTFLAGS "-C target-feature=+crt-static"
cf restage my-app
```

## Advanced Topics

### Optimizing Build Performance

1. **Minimize Dependencies**:
   * Use fewer dependencies when possible
   * Consider using workspace members for modular apps

2. **Optimize Caching**:
   * Pin dependency versions for better cache hits
   * Use a consistent Rust version

3. **Build Configuration**:
   * For faster builds with larger binaries:
     ```Shell
     cf set-env my-app RUSTFLAGS "-C opt-level=1"
     ```
   * For smaller binaries (but slower builds):
     ```Shell
     cf set-env my-app RUSTFLAGS "-C opt-level=z -C lto=fat"
     ```

### Memory Considerations

If your build fails due to memory constraints:

```Shell
cf push my-app -b https://github.com/tristanpoland/CF-Rust-Buildpack -m 2G
```

### Handling Large Crates

For applications with many dependencies:

```Shell
cf set-staging-environment-variable-group '{"CF_STAGING_TIMEOUT": 30}'
```

### Security Best Practices

1. **Dependency Auditing**:
   * Run `cargo audit` in your CI pipeline
   * Keep dependencies updated

2. **Pinned Versions**:
   * Use `Cargo.lock` in your deployments
   * Pin the Rust version for consistency

3. **Minimal Images**:
   * Consider using `x86_64-unknown-linux-musl` target for static linking

## Troubleshooting

### Common Issues

#### Build Failures

If your build fails, check the logs for detailed error information:

```Shell
cf logs my-app --recent
```

The buildpack includes intelligent error detection for:

* Missing linkers or system dependencies
* Incompatible Rust versions
* Network failures
* Memory issues

#### Application Crashes

If your application crashes on startup:

1. Ensure it's listening on the port specified by the `PORT` environment variable
2. Check for missing runtime dependencies
3. Verify it's built for the correct target architecture

#### Slow Builds

If builds are taking too long:

1. Check cache effectiveness with `cf logs`
2. Consider reducing dependencies
3. Use a faster Rust profile for development:
   ```Shell
   cf set-env my-app CARGO_BUILD_FLAGS "--profile dev-fast"
   ```

### Debugging

Enable debug mode for more verbose output:

```Shell
cf set-env my-app RUST_DEBUG true
cf restage my-app
```

## Custom Buildpack Modifications

### Forking and Customizing

1. Fork the buildpack repository
2. Modify the scripts in `bin/` and `lib/` directories
3. Update your application to use your custom buildpack:
   ```Shell
   cf push my-app -b https://github.com/tristanpoland/CF-Rust-Buildpack
   ```

### Adding System Dependencies

The buildpack uses the Cloud Foundry stack's system libraries. If you need additional system dependencies, consider:

1. Using the apt-buildpack in conjunction with this buildpack
2. Building with the `x86_64-unknown-linux-musl` target for static linking
3. Creating a custom Docker image with your dependencies (if using cflinuxfs3)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Testing

To test buildpack changes locally:

```Shell
CF_STACK=cflinuxfs4 ./bin/detect /path/to/rust/app
CF_STACK=cflinuxfs4 ./bin/compile /path/to/rust/app /tmp/cache
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

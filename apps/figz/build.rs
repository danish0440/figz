//! Windows: embed the icon and version info in figz.exe and size its main thread's stack
//! (no-op elsewhere). Also bakes the build channel and the version the app reports.
//!
//! The channel comes from `FIGZ_BUILD_CHANNEL`: unset, empty or `stable` is the stable build;
//! `nightly-v1` needs an explicit `FIGZ_VERSION` (or the wrappers' `FIGZ_OVERRIDE_VERSION`)
//! that names the exact feed identity. A missing resource compiler stays a warning unless
//! `FIGZ_REQUIRE_WINRES=1` (set by the packaging scripts) makes it an error.

#[path = "src/build_channel.rs"]
mod build_channel;

fn main() {
    println!("cargo::rerun-if-changed=build.rs");
    println!("cargo::rustc-check-cfg=cfg(windows_slim_errors)");
    println!("cargo::rustc-check-cfg=cfg(figz_nightly_v1)");
    println!("cargo::rerun-if-changed=../../assets/app-icon/figz.ico");
    println!("cargo::rerun-if-changed=../../assets/app-icon/figz-nightly.ico");
    println!("cargo::rerun-if-env-changed=FIGZ_BUILD_CHANNEL");
    println!("cargo::rerun-if-env-changed=FIGZ_VERSION");
    println!("cargo::rerun-if-env-changed=FIGZ_OVERRIDE_VERSION");
    println!("cargo::rerun-if-env-changed=FIGZ_REQUIRE_WINRES");

    let nightly = match std::env::var("FIGZ_BUILD_CHANNEL").as_deref() {
        Ok("nightly-v1") => {
            println!("cargo::rustc-cfg=figz_nightly_v1");
            true
        }
        // An empty value (an unset CI input) means the default stable build.
        Ok("stable" | "") | Err(std::env::VarError::NotPresent) => false,
        _ => {
            eprintln!("unsupported FIGZ_BUILD_CHANNEL (expected stable or nightly-v1)");
            std::process::exit(1);
        }
    };
    let built_version = if nightly {
        // `packaging/nightly-common.sh` and `packaging/windows/nightly.ps1` pass the prepared
        // version as FIGZ_OVERRIDE_VERSION; a caller that already set FIGZ_VERSION works too.
        let supplied = std::env::var("FIGZ_OVERRIDE_VERSION").ok().filter(|v| !v.is_empty()).or_else(|| std::env::var("FIGZ_VERSION").ok());
        match supplied {
            Some(version) if build_channel::is_nightly_version(&version) => version,
            _ => {
                eprintln!("nightly-v1 requires an explicit FIGZ_VERSION (or FIGZ_OVERRIDE_VERSION) feed identity");
                std::process::exit(1);
            }
        }
    } else {
        std::env::var("CARGO_PKG_VERSION").unwrap_or_default()
    };
    println!("cargo::rustc-env=FIGZ_BUILT_VERSION={built_version}");

    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_os == "windows" {
        let mut res = winresource::WindowsResource::new();
        let ico = build_channel::windows_icon_path(nightly);
        if std::path::Path::new(ico).exists() {
            res.set_icon(ico);
        }
        res.set("ProductName", if nightly { "FigZ Nightly" } else { "FigZ" })
            .set("FileDescription", if nightly { "FigZ Nightly interface design and prototyping" } else { "FigZ" })
            .set("CompanyName", "Upstream")
            .set("OriginalFilename", "figz.exe")
            .set("InternalName", "figz");
        if nightly {
            // The Launcher verifies the PE ProductVersion against the exact feed identity, not FileVersion.
            res.set("ProductVersion", &built_version);
        }
        if let Err(e) = res.compile() {
            if std::env::var_os("FIGZ_REQUIRE_WINRES").is_some() {
                // The workspace denies `clippy::panic`, build scripts included: stop the build with
                // the reason on stderr, as the channel check above does.
                eprintln!("embedding Windows resources failed: {e}");
                std::process::exit(1);
            }
            println!("cargo::warning=winresource: {e}");
        }
        // Windows starts the main thread with 1 MB of stack, Linux and macOS with 8 MB. Layers
        // nest up to 256 deep in an export, and that recursion needs the same room everywhere.
        let msvc = std::env::var("CARGO_CFG_TARGET_ENV").as_deref() == Ok("msvc");
        println!("cargo::rustc-link-arg-bins={}", if msvc { "/STACK:8388608" } else { "-Wl,--stack,8388608" });
    }
    let sha = std::env::var("FIGZ_BUILD_SHA").unwrap_or_default();
    println!("cargo::rustc-env=FIGZ_BUILD_SHA={sha}");
    println!("cargo::rerun-if-env-changed=FIGZ_BUILD_SHA");
}

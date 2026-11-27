use devtools_inspector::adapter::{validate_path, validate_report};
use serde_json::json;

#[test]
fn rejects_invalid_paths() {
    for path in ["", "relative", "C:\\does-not-exist-929182", "\\\\server\\share", "\\\\?\\C:\\"] {
        assert!(validate_path(path).is_err(), "{path}");
    }
}

#[test]
fn rejects_malformed_and_wrong_schema() {
    assert!(validate_report("not json", "C:\\fixture").is_err());
    assert!(validate_report(&json!({"schemaVersion":2}).to_string(), "C:\\fixture").is_err());
    assert!(validate_report(&json!({"schemaVersion":1}).to_string(), "C:\\fixture").is_err());
}

#[test]
fn actual_cli_adapter_parity_spaces_unicode() {
    use std::{sync::{Arc,atomic::AtomicBool},process::Command};
    let fixture=std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("evidence").join(format!("fixture space ü {}",std::process::id()));
    std::fs::create_dir_all(&fixture).unwrap();
    std::fs::write(fixture.join("Cargo.toml"),"# inert marker only").unwrap();
    std::fs::write(fixture.join("README.md"),"inert fixture").unwrap();
    let path=fixture.to_str().unwrap().to_string();
    assert!(validate_path(&path).is_ok());
    let result=devtools_inspector::adapter::inspect(path.clone(),17,Arc::new(AtomicBool::new(false)));
    assert_eq!(result.status,"completed","{result:?}");
    let cfg:serde_json::Value=serde_json::from_str(include_str!("../host-config.json")).unwrap();
    let helper=std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join(cfg["helper"].as_str().unwrap()).canonicalize().unwrap();
    let baseline=fixture.join("baseline.ps1");
    std::fs::write(&baseline,"param([string]$Helper,[string]$ProjectPath)\n[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)\n& $Helper -ProjectPath $ProjectPath -MaxDepth 2 -Json\n").unwrap();
    let cli=Command::new(cfg["pwsh"].as_str().unwrap()).args(["-NoProfile","-NonInteractive","-File",baseline.to_str().unwrap(),"-Helper",helper.to_str().unwrap().strip_prefix("\\\\?\\").unwrap_or(helper.to_str().unwrap()),"-ProjectPath",&path]).output().unwrap();
    assert!(cli.status.success());
    let mut expected=validate_report(std::str::from_utf8(&cli.stdout).unwrap(),&path).unwrap();
    let mut actual=result.report.unwrap();
    expected.as_object_mut().unwrap().remove("observedUtc");actual.as_object_mut().unwrap().remove("observedUtc");
    assert_eq!(actual,expected);
    assert_eq!(actual["markers"][0]["kind"],"Rust");
    let cancelled=devtools_inspector::adapter::inspect(path,18,Arc::new(AtomicBool::new(true)));
    assert_eq!(cancelled.status,"cancelled");assert_eq!(cancelled.exit_code,None);
    std::fs::remove_dir_all(fixture).unwrap();
}

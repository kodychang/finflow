use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use tauri::{AppHandle, Manager};

const FIRST_RUN_MARKER_FILE: &str = "first-run-setup.json";

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FirstRunStatus {
    pub should_show_setup: bool,
    pub marker_file: String,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct FirstRunMarker {
    completed_at: String,
}

fn marker_file(app: &AppHandle) -> Result<PathBuf, String> {
    app.path()
        .app_data_dir()
        .map(|path| path.join(FIRST_RUN_MARKER_FILE))
        .map_err(|error| format!("Could not locate first-run marker: {error}"))
}

pub fn first_run_status(app: &AppHandle) -> Result<FirstRunStatus, String> {
    let marker = marker_file(app)?;
    Ok(FirstRunStatus {
        should_show_setup: !marker.exists(),
        marker_file: marker.to_string_lossy().to_string(),
    })
}

pub fn complete_first_run_setup(app: &AppHandle) -> Result<FirstRunStatus, String> {
    let marker = marker_file(app)?;
    if let Some(parent) = marker.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("Could not create first-run marker folder: {error}"))?;
    }

    let completed_at = chrono::Local::now().to_rfc3339();
    let payload = serde_json::to_vec_pretty(&FirstRunMarker { completed_at })
        .map_err(|error| format!("Could not encode first-run marker: {error}"))?;
    fs::write(&marker, payload)
        .map_err(|error| format!("Could not write first-run marker: {error}"))?;

    first_run_status(app)
}

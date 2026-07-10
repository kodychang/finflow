use chrono::Local;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use tauri::{AppHandle, Emitter, Manager, Url};

mod setup;

#[derive(Debug, Serialize)]
struct AppPaths {
    root: String,
    backups: String,
    imports: String,
    exports: String,
    temp: String,
    state_file: String,
    is_custom: bool,
    config_file: String,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct StorageConfig {
    custom_root: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SavePayload {
    backup: Value,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ExportPayload {
    backup: Value,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct TextFilePayload {
    path: String,
    contents: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct BinaryFilePayload {
    path: String,
    contents: Vec<u8>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct TempBinaryFilePayload {
    file_name: String,
    contents: Vec<u8>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct OpenedBinaryFile {
    path: String,
    file_name: String,
    content_type: String,
    contents: Vec<u8>,
}

fn default_app_root(app: &AppHandle) -> Result<PathBuf, String> {
    app.path()
        .app_data_dir()
        .map_err(|error| format!("Could not locate app data directory: {error}"))
}

fn config_file(app: &AppHandle) -> Result<PathBuf, String> {
    Ok(default_app_root(app)?.join("storage-config.json"))
}

fn read_storage_config(app: &AppHandle) -> Result<StorageConfig, String> {
    let path = config_file(app)?;
    if !path.exists() {
        return Ok(StorageConfig { custom_root: None });
    }
    let data = fs::read_to_string(&path)
        .map_err(|error| format!("Could not read storage config: {error}"))?;
    serde_json::from_str(&data)
        .map_err(|error| format!("Storage config is not valid JSON: {error}"))
}

fn write_storage_config(app: &AppHandle, config: &StorageConfig) -> Result<(), String> {
    let root = default_app_root(app)?;
    fs::create_dir_all(&root)
        .map_err(|error| format!("Could not create app config folder: {error}"))?;
    let data = serde_json::to_vec_pretty(config)
        .map_err(|error| format!("Could not encode storage config: {error}"))?;
    fs::write(config_file(app)?, data)
        .map_err(|error| format!("Could not write storage config: {error}"))
}

fn storage_root(app: &AppHandle) -> Result<(PathBuf, bool), String> {
    let config = read_storage_config(app)?;
    if let Some(custom_root) = config.custom_root.filter(|path| !path.trim().is_empty()) {
        return Ok((PathBuf::from(custom_root), true));
    }
    Ok((default_app_root(app)?, false))
}

fn storage_paths(app: &AppHandle) -> Result<(PathBuf, AppPaths), String> {
    let (root, is_custom) = storage_root(app)?;
    let backups = root.join("backups");
    let imports = root.join("imports");
    let exports = root.join("exports");
    let temp = root.join("temp");
    let state_file = root.join("state.json");
    let config_file = config_file(app)?;

    let paths = AppPaths {
        root: root.to_string_lossy().to_string(),
        backups: backups.to_string_lossy().to_string(),
        imports: imports.to_string_lossy().to_string(),
        exports: exports.to_string_lossy().to_string(),
        temp: temp.to_string_lossy().to_string(),
        state_file: state_file.to_string_lossy().to_string(),
        is_custom,
        config_file: config_file.to_string_lossy().to_string(),
    };

    Ok((root, paths))
}

fn create_storage_dirs(root: &Path) -> Result<(), String> {
    fs::create_dir_all(root.join("backups"))
        .map_err(|error| format!("Could not create backups folder: {error}"))?;
    fs::create_dir_all(root.join("imports"))
        .map_err(|error| format!("Could not create imports folder: {error}"))?;
    fs::create_dir_all(root.join("exports"))
        .map_err(|error| format!("Could not create exports folder: {error}"))?;
    fs::create_dir_all(root.join("temp"))
        .map_err(|error| format!("Could not create temp folder: {error}"))?;
    Ok(())
}

fn validate_backup(backup: &Value) -> Result<(), String> {
    let version = backup
        .get("version")
        .and_then(Value::as_i64)
        .ok_or("Backup is missing numeric version.")?;
    if version != 1 {
        return Err(format!("Unsupported backup version: {version}"));
    }

    for key in ["documents", "customers", "issuers", "products"] {
        if !backup.get(key).is_some_and(Value::is_array) {
            return Err(format!("Backup is missing array field: {key}"));
        }
    }

    Ok(())
}

fn write_json(path: &Path, value: &Value) -> Result<(), String> {
    let data = serde_json::to_vec_pretty(value)
        .map_err(|error| format!("Could not encode backup JSON: {error}"))?;
    fs::write(path, data).map_err(|error| format!("Could not write file: {error}"))
}

#[tauri::command]
fn init_app_storage(app: AppHandle) -> Result<AppPaths, String> {
    let (root, paths) = storage_paths(&app)?;
    create_storage_dirs(&root)?;
    if !root.join("state.json").exists() {
        write_json(&root.join("state.json"), &empty_backup())?;
    }
    Ok(paths)
}

#[tauri::command]
fn set_data_root(app: AppHandle, path: String) -> Result<AppPaths, String> {
    let clean_path = path.trim();
    if clean_path.is_empty() {
        return Err("Data folder path is empty.".to_string());
    }
    let root = PathBuf::from(clean_path);
    fs::create_dir_all(&root)
        .map_err(|error| format!("Could not create selected data folder: {error}"))?;
    create_storage_dirs(&root)?;
    if !root.join("state.json").exists() {
        write_json(&root.join("state.json"), &empty_backup())?;
    }
    write_storage_config(
        &app,
        &StorageConfig {
            custom_root: Some(root.to_string_lossy().to_string()),
        },
    )?;
    init_app_storage(app)
}

#[tauri::command]
fn reset_data_root(app: AppHandle) -> Result<AppPaths, String> {
    let path = config_file(&app)?;
    if path.exists() {
        fs::remove_file(path)
            .map_err(|error| format!("Could not reset data folder config: {error}"))?;
    }
    init_app_storage(app)
}

#[tauri::command]
fn load_state(app: AppHandle) -> Result<Value, String> {
    let (root, _) = storage_paths(&app)?;
    create_storage_dirs(&root)?;
    let path = root.join("state.json");
    if !path.exists() {
        return Ok(empty_backup());
    }
    let data = fs::read_to_string(&path)
        .map_err(|error| format!("Could not read local state: {error}"))?;
    let backup: Value = serde_json::from_str(&data)
        .map_err(|error| format!("Local state is not valid JSON: {error}"))?;
    validate_backup(&backup)?;
    Ok(backup)
}

#[tauri::command]
fn save_state(app: AppHandle, payload: SavePayload) -> Result<(), String> {
    validate_backup(&payload.backup)?;
    let (root, _) = storage_paths(&app)?;
    create_storage_dirs(&root)?;
    write_json(&root.join("state.json"), &payload.backup)
}

#[tauri::command]
fn export_backup(app: AppHandle, payload: ExportPayload) -> Result<String, String> {
    validate_backup(&payload.backup)?;
    let (root, _) = storage_paths(&app)?;
    create_storage_dirs(&root)?;

    let file_name = format!(
        "shoko-forms-backup-{}.shokobackup",
        Local::now().format("%Y%m%d-%H%M%S")
    );
    let export_path = root.join("exports").join(file_name);
    write_json(&export_path, &payload.backup)?;

    let backup_copy = root
        .join("backups")
        .join(export_path.file_name().unwrap_or_default());
    fs::copy(&export_path, backup_copy)
        .map_err(|error| format!("Could not copy backup to history folder: {error}"))?;

    Ok(export_path.to_string_lossy().to_string())
}

#[tauri::command]
fn import_backup_text(app: AppHandle, json_text: String, mode: String) -> Result<Value, String> {
    let incoming: Value = serde_json::from_str(&json_text)
        .map_err(|error| format!("Backup file is not valid JSON: {error}"))?;
    validate_backup(&incoming)?;

    let current = load_state(app.clone()).unwrap_or_else(|_| empty_backup());
    let merged = if mode == "replace" {
        incoming
    } else {
        merge_backups(current, incoming)
    };

    save_state(
        app.clone(),
        SavePayload {
            backup: merged.clone(),
        },
    )?;

    let (root, _) = storage_paths(&app)?;
    create_storage_dirs(&root)?;
    let file_name = format!(
        "imported-shoko-forms-backup-{}.shokobackup",
        Local::now().format("%Y%m%d-%H%M%S")
    );
    write_json(&root.join("imports").join(file_name), &merged)?;

    Ok(merged)
}

#[tauri::command]
fn write_text_file(payload: TextFilePayload) -> Result<(), String> {
    let clean_path = payload.path.trim();
    if clean_path.is_empty() {
        return Err("保存路徑是空的。".to_string());
    }
    let path = PathBuf::from(clean_path);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("Could not create output folder: {error}"))?;
    }
    fs::write(path, payload.contents).map_err(|error| format!("Could not write file: {error}"))
}

#[tauri::command]
fn write_binary_file(payload: BinaryFilePayload) -> Result<(), String> {
    let clean_path = payload.path.trim();
    if clean_path.is_empty() {
        return Err("保存路徑是空的。".to_string());
    }
    let path = PathBuf::from(clean_path);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("Could not create output folder: {error}"))?;
    }
    fs::write(path, payload.contents).map_err(|error| format!("Could not write file: {error}"))
}

#[tauri::command]
fn write_temp_binary_file(
    app: AppHandle,
    payload: TempBinaryFilePayload,
) -> Result<String, String> {
    let (_, paths) = storage_paths(&app)?;
    let temp_dir = PathBuf::from(paths.temp);
    fs::create_dir_all(&temp_dir)
        .map_err(|error| format!("Could not create temp folder: {error}"))?;

    let file_name = sanitize_file_name(&payload.file_name);
    let path = temp_dir.join(file_name);
    fs::write(&path, payload.contents)
        .map_err(|error| format!("Could not write temp file: {error}"))?;
    Ok(path.to_string_lossy().to_string())
}

#[tauri::command]
fn open_local_file(path: String) -> Result<(), String> {
    let clean_path = path.trim();
    if clean_path.is_empty() {
        return Err("檔案路徑是空的。".to_string());
    }
    tauri_plugin_opener::open_path(PathBuf::from(clean_path), None::<&str>)
        .map_err(|error| format!("Could not open file: {error}"))
}

#[tauri::command]
fn pending_open_files() -> Vec<String> {
    env::args()
        .skip(1)
        .filter(|argument| !argument.starts_with('-'))
        .map(PathBuf::from)
        .filter(|path| path.is_file() && is_supported_external_attachment(path))
        .map(|path| path.to_string_lossy().to_string())
        .collect()
}

fn opened_url_paths(urls: Vec<Url>) -> Vec<String> {
    urls.into_iter()
        .filter_map(|url| url.to_file_path().ok())
        .filter(|path| path.is_file() && is_supported_external_attachment(path))
        .map(|path| path.to_string_lossy().to_string())
        .collect()
}

#[tauri::command]
fn read_binary_file(path: String) -> Result<OpenedBinaryFile, String> {
    let clean_path = path.trim();
    if clean_path.is_empty() {
        return Err("檔案路徑是空的。".to_string());
    }
    let path = PathBuf::from(clean_path);
    if !is_supported_external_attachment(&path) {
        return Err("Shoko 只支援從系統開啟 PDF 或圖片檔案。".to_string());
    }
    let contents = fs::read(&path).map_err(|error| format!("Could not read file: {error}"))?;
    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("attachment")
        .to_string();
    Ok(OpenedBinaryFile {
        path: path.to_string_lossy().to_string(),
        file_name,
        content_type: content_type_for_path(&path).to_string(),
        contents,
    })
}

#[tauri::command]
fn get_first_run_status(app: AppHandle) -> Result<setup::FirstRunStatus, String> {
    setup::first_run_status(&app)
}

#[tauri::command]
fn complete_first_run_setup(app: AppHandle) -> Result<setup::FirstRunStatus, String> {
    setup::complete_first_run_setup(&app)
}

fn sanitize_file_name(file_name: &str) -> String {
    let clean: String = file_name
        .chars()
        .map(|character| match character {
            '/' | '\\' | ':' | '*' | '?' | '"' | '<' | '>' | '|' => '-',
            _ => character,
        })
        .collect();
    let trimmed = clean.trim();
    if trimmed.is_empty() {
        "shoko-document.pdf".to_string()
    } else {
        trimmed.to_string()
    }
}

fn is_supported_external_attachment(path: &Path) -> bool {
    matches!(
        path.extension()
            .and_then(|extension| extension.to_str())
            .unwrap_or("")
            .to_ascii_lowercase()
            .as_str(),
        "pdf" | "png" | "jpg" | "jpeg" | "webp" | "gif" | "heic" | "heif"
    )
}

fn content_type_for_path(path: &Path) -> &'static str {
    match path
        .extension()
        .and_then(|extension| extension.to_str())
        .unwrap_or("")
        .to_ascii_lowercase()
        .as_str()
    {
        "pdf" => "application/pdf",
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "webp" => "image/webp",
        "gif" => "image/gif",
        "heic" => "image/heic",
        "heif" => "image/heif",
        _ => "application/octet-stream",
    }
}

fn merge_backups(mut current: Value, incoming: Value) -> Value {
    for key in [
        "documents",
        "customers",
        "issuers",
        "products",
        "textTemplates",
    ] {
        let mut existing = current
            .get(key)
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();
        let additions = incoming
            .get(key)
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();

        for item in additions {
            let incoming_id = item.get("id").and_then(Value::as_str);
            let exists = incoming_id.is_some_and(|id| {
                existing
                    .iter()
                    .any(|candidate| candidate.get("id").and_then(Value::as_str) == Some(id))
            });
            if !exists {
                existing.push(item);
            }
        }
        current[key] = Value::Array(existing);
    }

    if current.get("draft").is_none() || current.get("draft") == Some(&Value::Null) {
        current["draft"] = incoming.get("draft").cloned().unwrap_or(Value::Null);
    }
    current["exportedAt"] = Value::String(Local::now().to_rfc3339());
    current
}

fn empty_backup() -> Value {
    serde_json::json!({
        "version": 1,
        "exportedAt": Local::now().to_rfc3339(),
        "documents": [],
        "customers": [],
        "issuers": [],
        "products": [],
        "draft": null,
        "textTemplates": []
    })
}

pub fn run() {
    // Core form/data commands are registered independently from first-run setup.
    // Closing or completing the setup dialog must not affect these handlers.
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            init_app_storage,
            set_data_root,
            reset_data_root,
            load_state,
            save_state,
            export_backup,
            import_backup_text,
            write_text_file,
            write_binary_file,
            write_temp_binary_file,
            open_local_file,
            pending_open_files,
            read_binary_file,
            get_first_run_status,
            complete_first_run_setup
        ])
        .build(tauri::generate_context!())
        .expect("error while building Shoko Forms Desktop")
        .run(|app, event| {
            #[cfg(any(target_os = "macos", target_os = "ios", target_os = "android"))]
            if let tauri::RunEvent::Opened { urls } = event {
                let paths = opened_url_paths(urls);
                if !paths.is_empty() {
                    let _ = app.emit("external-files-opened", paths);
                }
            }
        });
}

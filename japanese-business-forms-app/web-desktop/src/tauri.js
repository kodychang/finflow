import { invoke } from "@tauri-apps/api/core";
import { backupFileName, EMPTY_BACKUP, mergeBackups, normalizeBackup } from "./backup";

const LOCAL_STORAGE_KEY = "shoko.forms.desktop.state.v1";
const FIRST_RUN_SETUP_KEY = "shoko.forms.desktop.firstRunSetup.v1";

export function isTauri() {
  return Boolean(window.__TAURI_INTERNALS__);
}

export async function initStorage() {
  if (isTauri()) {
    return invoke("init_app_storage");
  }
  return {
    root: "瀏覽器預覽模式：使用 localStorage",
    backups: "瀏覽器預覽模式",
    imports: "瀏覽器預覽模式",
    exports: "瀏覽器下載資料夾",
    temp: "瀏覽器預覽模式",
    state_file: "localStorage",
    is_custom: false,
    config_file: "localStorage",
  };
}

export async function getFirstRunStatus() {
  if (isTauri()) {
    return invoke("get_first_run_status");
  }
  return {
    shouldShowSetup: !localStorage.getItem(FIRST_RUN_SETUP_KEY),
    markerFile: "localStorage",
  };
}

export async function completeFirstRunSetup() {
  if (isTauri()) {
    return invoke("complete_first_run_setup");
  }
  localStorage.setItem(
    FIRST_RUN_SETUP_KEY,
    JSON.stringify({
      completedAt: new Date().toISOString(),
    }),
  );
  return getFirstRunStatus();
}

export async function chooseDataFolder() {
  if (!isTauri()) return null;
  const { open } = await import("@tauri-apps/plugin-dialog");
  return open({
    directory: true,
    multiple: false,
    title: "選擇 Shoko Forms 資料夾",
  });
}

export async function setDataRoot(path) {
  if (!isTauri()) {
    return initStorage();
  }
  return invoke("set_data_root", { path });
}

export async function resetDataRoot() {
  if (!isTauri()) {
    localStorage.removeItem(LOCAL_STORAGE_KEY);
    return initStorage();
  }
  return invoke("reset_data_root");
}

export async function loadState() {
  if (isTauri()) {
    return normalizeBackup(await invoke("load_state"));
  }
  const stored = localStorage.getItem(LOCAL_STORAGE_KEY);
  if (!stored) return EMPTY_BACKUP;
  return normalizeBackup(JSON.parse(stored));
}

export async function saveState(backup) {
  const normalized = normalizeBackup({ ...backup, exportedAt: new Date().toISOString() });
  if (isTauri()) {
    await invoke("save_state", { payload: { backup: normalized } });
  } else {
    localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(normalized));
  }
  return normalized;
}

export async function importBackupText(jsonText, mode, currentBackup) {
  if (isTauri()) {
    return normalizeBackup(await invoke("import_backup_text", { jsonText, mode }));
  }
  const incoming = normalizeBackup(JSON.parse(jsonText));
  const next = mode === "replace" ? incoming : mergeBackups(currentBackup, incoming);
  return saveState(next);
}

export async function exportBackup(backup) {
  const normalized = normalizeBackup({ ...backup, exportedAt: new Date().toISOString() });
  if (isTauri()) {
    return invoke("export_backup", { payload: { backup: normalized } });
  }
  const blob = new Blob([JSON.stringify(normalized, null, 2)], {
    type: "application/vnd.shoko.forms.backup+json",
  });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = backupFileName();
  anchor.click();
  URL.revokeObjectURL(url);
  return "瀏覽器已下載 .shokobackup 檔案";
}

export async function saveTextFileWithDialog(contents, defaultPath, filters = [{ name: "HTML", extensions: ["html"] }]) {
  if (isTauri()) {
    const { save } = await import("@tauri-apps/plugin-dialog");
    const path = await save({
      defaultPath,
      filters,
      title: "保存文件",
    });
    if (!path) return null;
    await invoke("write_text_file", { payload: { path, contents } });
    return path;
  }

  const extension = filters[0]?.extensions?.[0] ?? "txt";
  const type = extension === "html" ? "text/html;charset=utf-8" : "text/plain;charset=utf-8";
  const blob = new Blob([contents], { type });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = defaultPath;
  anchor.click();
  URL.revokeObjectURL(url);
  return "瀏覽器已下載文件";
}

export async function saveBinaryFileWithDialog(bytes, defaultPath, filters = [{ name: "PDF", extensions: ["pdf"] }]) {
  if (isTauri()) {
    const { save } = await import("@tauri-apps/plugin-dialog");
    const path = await save({
      defaultPath,
      filters,
      title: "保存文件",
    });
    if (!path) return null;
    await invoke("write_binary_file", { payload: { path, contents: Array.from(bytes) } });
    return path;
  }

  const blob = new Blob([bytes], { type: "application/pdf" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = defaultPath;
  anchor.click();
  URL.revokeObjectURL(url);
  return "瀏覽器已下載 PDF 文件";
}

export async function writeTempBinaryFile(bytes, fileName) {
  if (isTauri()) {
    return invoke("write_temp_binary_file", { payload: { fileName, contents: Array.from(bytes) } });
  }

  const blob = new Blob([bytes], { type: "application/pdf" });
  const url = URL.createObjectURL(blob);
  window.open(url, "_blank", "noopener,noreferrer");
  return "瀏覽器已開啟 PDF 預覽";
}

export async function openLocalFile(path) {
  if (isTauri()) {
    await invoke("open_local_file", { path });
    return;
  }
  return path;
}

export async function pendingOpenFiles() {
  if (!isTauri()) return [];
  return invoke("pending_open_files");
}

export async function readBinaryFile(path) {
  if (!isTauri()) {
    throw new Error("只有桌面版可以讀取系統開啟的檔案。");
  }
  return invoke("read_binary_file", { path });
}

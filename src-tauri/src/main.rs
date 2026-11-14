#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
use octane_core::{analyze, export_new, Report};
use std::{path::PathBuf, sync::Mutex};
use tauri::Manager;

#[derive(Default)]
struct Analysis(Mutex<Option<Report>>);

async fn process(paths: Vec<PathBuf>, state: tauri::State<'_, Analysis>) -> Result<Report, String> {
    let report = tauri::async_runtime::spawn_blocking(move || analyze(paths)).await.map_err(|e| e.to_string())??;
    *state.0.lock().map_err(|e| e.to_string())? = Some(report.clone());
    Ok(report)
}
#[tauri::command]
async fn choose_files(state: tauri::State<'_, Analysis>) -> Result<Option<Report>, String> {
    let paths = tauri::async_runtime::spawn_blocking(|| rfd::FileDialog::new().set_title("Choose files to analyze").pick_files()).await.map_err(|e| e.to_string())?;
    match paths { Some(paths) => process(paths, state).await.map(Some), None => Ok(None) }
}
#[tauri::command]
async fn load_sample(app: tauri::AppHandle, state: tauri::State<'_, Analysis>) -> Result<Report, String> {
    let dir = app.path().resource_dir().map_err(|e| e.to_string())?.join("fixtures");
    let mut paths = std::fs::read_dir(dir).map_err(|e| e.to_string())?.map(|e| e.map(|e| e.path())).collect::<Result<Vec<_>, _>>().map_err(|e| e.to_string())?;
    paths.sort(); process(paths, state).await
}
#[tauri::command]
async fn export_report(state: tauri::State<'_, Analysis>) -> Result<Option<String>, String> {
    let report = state.0.lock().map_err(|e| e.to_string())?.clone().ok_or("Analyze files first")?;
    tauri::async_runtime::spawn_blocking(move || {
        let path = rfd::FileDialog::new().set_file_name("octane-report.json").add_filter("JSON", &["json"]).save_file();
        match path { Some(path) => { export_new(&report, &path)?; Ok(Some(path.to_string_lossy().into_owned())) }, None => Ok(None) }
    }).await.map_err(|e| e.to_string())?
}
fn main() {
    tauri::Builder::default().manage(Analysis::default())
        .invoke_handler(tauri::generate_handler![choose_files, load_sample, export_report])
        .run(tauri::generate_context!()).expect("Octane failed to start");
}

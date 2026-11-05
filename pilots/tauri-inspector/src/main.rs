#![windows_subsystem = "windows"]
use std::sync::{Arc,Mutex,atomic::{AtomicBool,Ordering}};
use devtools_inspector::adapter::{self,Evidence};
#[derive(Default)]
struct Jobs(Mutex<Option<(u64,Arc<AtomicBool>)>>);
#[tauri::command]
async fn select_folder()->Result<Option<String>,String>{
    tauri::async_runtime::spawn_blocking(||rfd::FileDialog::new().set_title("Select project folder").pick_folder().map(|p|p.to_string_lossy().into_owned())).await.map_err(|e|e.to_string())
}
#[tauri::command]
async fn inspect(path:String,request_id:u64,state:tauri::State<'_,Jobs>)->Result<Evidence,String>{
    let flag=Arc::new(AtomicBool::new(false));
    {let mut jobs=state.0.lock().map_err(|_|"Job state unavailable")?;if jobs.is_some(){return Err("An inspection is already active.".into())}*jobs=Some((request_id,flag.clone()));}
    let result=tauri::async_runtime::spawn_blocking(move||adapter::inspect(path,request_id,flag)).await.map_err(|e|e.to_string());
    *state.0.lock().map_err(|_|"Job state unavailable")?=None;result
}
#[tauri::command]
fn cancel(request_id:u64,state:tauri::State<'_,Jobs>)->Result<(),String>{
    if let Some((id,flag))=&*state.0.lock().map_err(|_|"Job state unavailable")?{if *id==request_id{flag.store(true,Ordering::SeqCst)}}Ok(())
}
fn main(){
    tauri::Builder::default().manage(Jobs::default())
        .setup(|app|{
            use tauri::Manager;
            let config=app.config().app.windows[0].clone();
            let profile=std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("evidence/webview-profile");
            tauri::WebviewWindowBuilder::from_config(app,&config)?.data_directory(profile).build()?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![select_folder,inspect,cancel])
        .on_window_event(|window,event|{if matches!(event,tauri::WindowEvent::Destroyed){use tauri::Manager;if let Ok(guard)=window.state::<Jobs>().0.lock(){if let Some((_,flag))=&*guard{flag.store(true,Ordering::SeqCst)}}}})
        .run(tauri::generate_context!()).expect("Failed to open inspector window");
}

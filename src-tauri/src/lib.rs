use std::{
    io::{Read, Write},
    net::{TcpListener, TcpStream},
    path::Path,
    sync::Mutex,
    thread,
    time::{Duration, Instant},
};

use tauri::{Manager, WebviewUrl, WebviewWindowBuilder};
use tauri_plugin_shell::{process::CommandChild, ShellExt};

#[derive(Default)]
struct BackendState {
    child: Mutex<Option<CommandChild>>,
    api_base: Mutex<String>,
}

#[tauri::command]
fn get_api_base(state: tauri::State<'_, BackendState>) -> String {
    state.api_base.lock().map(|v| v.clone()).unwrap_or_default()
}

fn pick_local_port() -> Result<u16, String> {
    let listener = TcpListener::bind("127.0.0.1:0").map_err(|e| e.to_string())?;
    let port = listener.local_addr().map_err(|e| e.to_string())?.port();
    drop(listener);
    Ok(port)
}

fn sqlite_url(path: &Path) -> String {
    format!("sqlite:///{}", path.to_string_lossy().replace('\\', "/"))
}

fn encode_component(input: &str) -> String {
    input
        .bytes()
        .map(|b| match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                (b as char).to_string()
            }
            _ => format!("%{b:02X}"),
        })
        .collect()
}

fn wait_for_health(port: u16, timeout: Duration) -> Result<(), String> {
    let deadline = Instant::now() + timeout;
    while Instant::now() < deadline {
        if let Ok(mut stream) = TcpStream::connect(("127.0.0.1", port)) {
            let _ = stream.set_read_timeout(Some(Duration::from_millis(500)));
            let request = "GET /health HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n";
            if stream.write_all(request.as_bytes()).is_ok() {
                let mut response = String::new();
                if stream.read_to_string(&mut response).is_ok()
                    && response
                        .lines()
                        .next()
                        .map(|line| line.contains(" 200 "))
                        .unwrap_or(false)
                    && response.contains("\"ok\":true")
                {
                    return Ok(());
                }
            }
        }
        thread::sleep(Duration::from_millis(200));
    }
    Err("backend /health did not become ready in time".to_string())
}

#[cfg(windows)]
fn kill_process_tree(pid: u32) {
    use std::os::windows::process::CommandExt;

    let _ = std::process::Command::new("taskkill")
        .args(["/PID", &pid.to_string(), "/T", "/F"])
        .creation_flags(0x08000000)
        .output();
}

#[cfg(not(windows))]
fn kill_process_tree(_pid: u32) {}

fn stop_backend(state: &tauri::State<'_, BackendState>) {
    if let Ok(mut child_slot) = state.child.lock() {
        if let Some(child) = child_slot.take() {
            let pid = child.pid();
            kill_process_tree(pid);
            let _ = child.kill();
        }
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(BackendState::default())
        .invoke_handler(tauri::generate_handler![get_api_base])
        .setup(|app| {
            let port = pick_local_port()?;
            let api_base = format!("http://127.0.0.1:{port}");

            let app_data_dir = app.path().app_data_dir()?;
            std::fs::create_dir_all(&app_data_dir)?;
            let db_path = app_data_dir.join("ai_question_bank.db");
            let database_url = sqlite_url(&db_path);

            let mut command = app
                .shell()
                .sidecar("backend")
                .map_err(|e| format!("failed to create backend sidecar: {e}"))?;

            command = command
                .env("HOST", "127.0.0.1")
                .env("PORT", port.to_string())
                .env("AIQB_DESKTOP_MODE", "1")
                .env("AIQB_USER_DATA_DIR", app_data_dir.to_string_lossy().to_string())
                .env("AIQB_DESKTOP_DATABASE_URL", database_url);

            let (mut rx, child) = command
                .spawn()
                .map_err(|e| format!("failed to start backend sidecar: {e}"))?;

            let state = app.state::<BackendState>();
            {
                let mut slot = state.child.lock().map_err(|_| "backend state poisoned")?;
                *slot = Some(child);
            }
            {
                let mut slot = state.api_base.lock().map_err(|_| "api state poisoned")?;
                *slot = api_base.clone();
            }

            tauri::async_runtime::spawn(async move {
                use tauri_plugin_shell::process::CommandEvent;
                while let Some(event) = rx.recv().await {
                    match event {
                        CommandEvent::Stdout(line) => {
                            println!("[backend] {}", String::from_utf8_lossy(&line));
                        }
                        CommandEvent::Stderr(line) => {
                            eprintln!("[backend] {}", String::from_utf8_lossy(&line));
                        }
                        CommandEvent::Error(error) => {
                            eprintln!("[backend error] {error}");
                        }
                        CommandEvent::Terminated(payload) => {
                            eprintln!("[backend terminated] {:?}", payload);
                        }
                        _ => {}
                    }
                }
            });

            wait_for_health(port, Duration::from_secs(30)).map_err(|e| {
                stop_backend(&state);
                e
            })?;

            let start_url = format!(
                "v2-desktop/index.html?api_base={}",
                encode_component(&api_base)
            );
            WebviewWindowBuilder::new(app, "main", WebviewUrl::App(start_url.into()))
                .title("AI题库")
                .inner_size(1280.0, 820.0)
                .min_inner_size(960.0, 680.0)
                .resizable(true)
                .build()?;

            Ok(())
        })
        .on_window_event(|window, event| {
            if matches!(event, tauri::WindowEvent::CloseRequested { .. }) {
                let state = window.state::<BackendState>();
                stop_backend(&state);
                window.app_handle().exit(0);
            }
        })
        .build(tauri::generate_context!())
        .expect("error while building tauri application")
        .run(|app_handle, event| {
            if matches!(
                event,
                tauri::RunEvent::ExitRequested { .. } | tauri::RunEvent::Exit
            ) {
                let state = app_handle.state::<BackendState>();
                stop_backend(&state);
            }
        });
}

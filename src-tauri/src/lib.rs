use std::collections::HashMap;

#[tauri::command]
async fn get_weather(
    token: String,
    city: String,
    province: Option<String>,
) -> Result<String, String> {
    let client = reqwest::Client::new();
    let mut params = HashMap::new();
    params.insert("token", token.as_str());
    params.insert("city", city.as_str());
    if let Some(ref prov) = province {
        params.insert("province", prov.as_str());
    }

    let resp = client
        .post("https://v3.alapi.cn/api/tianqi")
        .json(&params)
        .send()
        .await
        .map_err(|e| format!("请求失败: {e}"))?;

    let text = resp.text().await.map_err(|e| format!("读取响应失败: {e}"))?;
    Ok(text)
}

#[tauri::command]
fn greet(name: &str) -> String {
    format!("Hello, {}! You've been greeted from Rust!", name)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![greet, get_weather])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

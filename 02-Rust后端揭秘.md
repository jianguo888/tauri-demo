# 🔧 Rust 后端揭秘 — 天气数据是怎么取回来的？

> **阅读对象**：看得懂一点点代码就行  
> **目标**：逐行读懂 Rust 后端代码，理解 HTTP 请求和 Tauri Command

---

## 1. 先看入口：main.rs

```rust
// 防止 Windows 上出现多余的控制台窗口（发布版本时生效）
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    tauri_demo_lib::run()   // 调用 lib.rs 中的 run() 函数
}
```

只有 5 行。它只是调用了 `lib.rs` 里的 `run()` 函数。真正的逻辑在 `lib.rs` 里。

---

## 2. 核心文件：lib.rs

```rust
use std::collections::HashMap;
```

这行导入了 Rust 标准库中的 `HashMap`（哈希表）。简单说就是一个 **"键-值"对** 的容器，类似 JavaScript 的对象 `{}` 或 Python 的字典 `dict`。

### 2.1 get_weather — 天气查询命令

```rust
#[tauri::command]                                // ← 标记：这是一个 Tauri 命令
async fn get_weather(
    token: String,                               // API 调用凭据
    city: String,                                // 城市名（如"北京"）
    province: Option<String>,                    // 省份（可选）
) -> Result<String, String> {                    // 返回 Result：成功→String，失败→String
```

#### `#[tauri::command]`
这是 **宏（macro）**，你可以理解为"魔法贴纸"。贴了这个标记的函数，前端就能用 `invoke("get_weather", ...)` 调用它。

#### `async fn`
**异步函数**。意思是不阻塞当前线程，等网络请求完成再继续。不然点一次查询整个 App 就卡住了。

#### `Option<String>`
Rust 里没有 `null`，用 `Option` 表示"可能有值，也可能没有"。对应前端的 `province: string | null`。

#### `Result<String, String>`
返回两种可能：要么成功返回一个字符串，要么失败返回错误信息。

---

### 2.2 组装请求参数

```rust
    let client = reqwest::Client::new();          // 创建一个 HTTP 客户端
    let mut params = HashMap::new();              // 创建一个空字典
    params.insert("token", token.as_str());       // 放入 token
    params.insert("city", city.as_str());         // 放入城市名
    if let Some(ref prov) = province {            // 如果 province 有值
        params.insert("province", prov.as_str()); // 放入省份名
    }
```

这段代码在拼一个字典，最终发出去的 POST 请求体就像：

```json
{
  "token": "ycd0krwbhl5v2w6iafblj94y5vzqdj",
  "city": "北京",
  "province": "北京"
}
```

---

### 2.3 发送 HTTP 请求

```rust
    let resp = client
        .post("https://v3.alapi.cn/api/tianqi")  // POST 到天气 API 地址
        .json(&params)                            // 把参数作为 JSON 发出去
        .send()                                   // 发送请求
        .await                                    // 等服务器响应
        .map_err(|e| format!("请求失败: {e}"))?;  // 如果出错，返回错误信息
```

这 6 行是链式调用，从 `client` 开始，一步步构建请求。`.await` 表示"等网络回来"。

`.map_err(...)?` 的意思是：如果 `send()` 返回错误，就把错误转换成 `"请求失败: xxx"` 并**提前返回**。`?` 是 Rust 的错误传播操作符。

---

### 2.4 读取响应并返回

```rust
    let text = resp
        .text()                                   // 把响应体读成字符串
        .await                                    // 等读取完成
        .map_err(|e| format!("读取响应失败: {e}"))?;

    Ok(text)                                      // 返回成功结果
}
```

ALAPI 返回的是 JSON 字符串，我们不做任何处理，直接返回给前端。前端拿到后再自己解析和渲染。

---

### 2.5 rust 程序的启动器

```rust
#[cfg_attr(mobile, tauri::mobile_entry_point)]    // 移动端入口标记
pub fn run() {
    tauri::Builder::default()                     // 创建 Tauri 应用构建器
        .plugin(tauri_plugin_opener::init())      // 注册"打开链接"插件
        .invoke_handler(                          // 注册命令处理器
            tauri::generate_handler![             // 把所有命令列在这里
                greet,                            // Hello World 示例
                get_weather                       // 天气查询 ← 我们写的
            ]
        )
        .run(tauri::generate_context!())          // 启动应用
        .expect("error while running tauri application");
}
```

这里最关键的是 `.invoke_handler()`，它告诉 Tauri：**前端可以调用的函数有 greet 和 get_weather**。如果你新增了一个命令但忘了在这里注册，前端就会报"命令不存在"。

---

## 3. Cargo.toml — Rust 的依赖清单

```toml
[dependencies]
tauri = { git = "https://github.com/richerfu/tauri", branch = "feat/open-harmony" }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
reqwest = { version = "0.12", features = ["json", "rustls-tls"], default-features = false }
```

每一行都是一个**外部库（crate）**：

| 库 | 用途 | 通俗理解 |
|----|------|---------|
| `tauri` | Tauri 框架本身 | 搭桥的人 |
| `serde` | 序列化/反序列化 | JSON ↔ Rust 数据结构的转换器 |
| `serde_json` | JSON 处理 | 专门处理 JSON 的 |
| `reqwest` | HTTP 请求 | 帮 Rust 上网要数据 |
| `tauri-plugin-opener` | 打开外部链接 | 点击链接跳转浏览器 |

特别注意：这里的 `tauri` 是从 `github.com/richerfu/tauri` 下载的，**不是官方版本**。这是一个专门为 OpenHarmony 做了适配的分支。

---

## 4. [patch.crates-io] — 补丁机制

```toml
[patch.crates-io]
openharmony-ability = { git = "https://github.com/harmony-contrib/openharmony-ability.git" }
tauri = { git = "https://github.com/richerfu/tauri", branch = "feat/open-harmony" }
```

`[patch]` 是 Rust 的"替换"机制。意思是：**项目中所有用到 tauri 的地方，都去这个 GitHub 地址下载，别去官方的源**。这样就保证整个项目用的是同一个适配了鸿蒙的版本。

---

## 5. 完整数据流回顾

```
前端 invoke("get_weather", {token, city, province})
     │
     ▼  Tauri 内部序列化参数
Rust 收到 → HashMap{"token":"...", "city":"北京"}
     │
     ▼  reqwest 发出 HTTP POST
https://v3.alapi.cn/api/tianqi
     │
     ▼  ALAPI 服务器处理
JSON 响应 {"success":true, "data":{"temp":26, ...}}
     │
     ▼  原路返回
前端收到 JSON 字符串 → 解析 → 渲染天气卡片
```

---

## 6. 小结

- Rust 后端只做一件事：**收参数 → 调 API → 返回结果**
- `#[tauri::command]` 让函数能被前端调用
- `reqwest` 是 Rust 发起 HTTP 请求的库
- `Cargo.toml` 是依赖清单，`[patch]` 负责版本替换

下一篇我们看前端 Vue 是怎么把数据变成漂亮卡片的 →

> 📄 [03-Vue前端之美.md](./03-Vue前端之美.md)

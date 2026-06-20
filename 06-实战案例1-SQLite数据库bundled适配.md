# 🗄️ 实战案例 1：给项目加 SQLite 数据库 — bundlled 模式的完整适配

> **目标**：在现有天气 App 中添加收藏城市功能（增删改查），验证 `rusqlite` + `bundled` 在鸿蒙上的可用性  
> **前置条件**：已 clone 项目并能成功编译运行

---

## 一、场景设计

天气 App 目前每次都要手动选城市。我们加一个"收藏城市"功能：

- 把当前查询的城市保存到本地数据库
- 下次打开 App 直接点一下就能查
- 支持删除已收藏的城市

```
┌─────────────────────────────┐
│  🌤 天气查询                  │
│                             │
│  📍 北京  ──→ [查询] [★收藏] │
│                             │
│  ┌─ 我的收藏 ──────────────┐ │
│  │ 北京  ☀️ 26°  [查询] [×] │ │
│  │ 上海  ☁️ 22°  [查询] [×] │ │
│  │ 深圳  🌧️ 28°  [查询] [×] │ │
│  └─────────────────────────┘ │
└─────────────────────────────┘
```

---

## 二、适配步骤

### Step 1：在 Cargo.toml 中添加 `rusqlite`

```toml
# src-tauri/Cargo.toml
[dependencies]
# ... 现有依赖 ...
rusqlite = { version = "0.32", features = ["bundled"] }
```

**关键点**：
- `features = ["bundled"]` 告诉 `rusqlite` **不要依赖系统的 libsqlite3**
- 它会自动下载 SQLite 的 C 源码，和你的 Rust 代码一起编译
- 最终 SQLite 被静态链接进 `.so`，鸿蒙手机不需要预装任何东西

### Step 2：验证编译

```bash
cd src-tauri && cargo check
```

如果能看到以下输出，说明适配成功：

```
Compiling libsqlite3-sys v0.28.0
Compiling rusqlite v0.32.0
Compiling tauri-demo v0.1.0
```

**如果编译失败**，最常见的问题是：

```
error: failed to run custom build command for 'libsqlite3-sys'
```

此时检查：
- 网络能否访问 crates.io（编译时下载 SQLite 源码）
- 是否有 C 编译器（`cc` crate 需要，macOS 上一般自带，鸿蒙上通过 NDK 提供）

---

## 三、核心代码实现

### 3.1 数据库模块：`src-tauri/src/db.rs`

新建一个独立的 Rust 源文件：

```rust
// src-tauri/src/db.rs
use rusqlite::{Connection, params};
use serde::Serialize;
use std::sync::Mutex;
use std::path::PathBuf;

#[derive(Debug, Serialize)]
pub struct FavoriteCity {
    pub id: i64,
    pub city: String,
    pub province: String,
}

/// 数据库管理器，用 Mutex 保证线程安全
pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    /// 创建/打开数据库文件
    pub fn new(app_dir: PathBuf) -> Result<Self, String> {
        // 确保目录存在
        std::fs::create_dir_all(&app_dir)
            .map_err(|e| format!("创建目录失败: {e}"))?;

        let db_path = app_dir.join("favorites.db");
        let conn = Connection::open(&db_path)
            .map_err(|e| format!("打开数据库失败: {e}"))?;

        // 建表（如果不存在）
        conn.execute(
            "CREATE TABLE IF NOT EXISTS favorites (
                id      INTEGER PRIMARY KEY AUTOINCREMENT,
                city    TEXT NOT NULL,
                province TEXT NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(city, province)
            )",
            [],
        ).map_err(|e| format!("建表失败: {e}"))?;

        Ok(Database {
            conn: Mutex::new(conn),
        })
    }

    /// 添加收藏
    pub fn add_favorite(&self, city: &str, province: &str) -> Result<(), String> {
        let conn = self.conn.lock().map_err(|e| format!("锁错误: {e}"))?;
        conn.execute(
            "INSERT OR IGNORE INTO favorites (city, province) VALUES (?1, ?2)",
            params![city, province],
        ).map_err(|e| format!("插入失败: {e}"))?;
        Ok(())
    }

    /// 删除收藏
    pub fn remove_favorite(&self, id: i64) -> Result<(), String> {
        let conn = self.conn.lock().map_err(|e| format!("锁错误: {e}"))?;
        conn.execute(
            "DELETE FROM favorites WHERE id = ?1",
            params![id],
        ).map_err(|e| format!("删除失败: {e}"))?;
        Ok(())
    }

    /// 获取所有收藏
    pub fn get_favorites(&self) -> Result<Vec<FavoriteCity>, String> {
        let conn = self.conn.lock().map_err(|e| format!("锁错误: {e}"))?;
        let mut stmt = conn
            .prepare("SELECT id, city, province FROM favorites ORDER BY created_at DESC")
            .map_err(|e| format!("查询准备失败: {e}"))?;

        let rows = stmt
            .query_map([], |row| {
                Ok(FavoriteCity {
                    id: row.get(0)?,
                    city: row.get(1)?,
                    province: row.get(2)?,
                })
            })
            .map_err(|e| format!("查询失败: {e}"))?;

        let mut result = Vec::new();
        for row in rows {
            result.push(row.map_err(|e| format!("读取行失败: {e}"))?);
        }
        Ok(result)
    }
}
```

### 3.2 注册 Tauri 命令

```rust
// src-tauri/src/lib.rs
mod db;    // ← 新加

use db::Database;
use std::sync::Mutex;
use tauri::Manager;

// 在数据库中保存了一个全局实例
struct AppState {
    db: Database,
}

// 收藏城市
#[tauri::command]
fn add_favorite(state: tauri::State<AppState>, city: String, province: String) -> Result<(), String> {
    state.db.add_favorite(&city, &province)
}

// 取消收藏
#[tauri::command]
fn remove_favorite(state: tauri::State<AppState>, id: i64) -> Result<(), String> {
    state.db.remove_favorite(id)
}

// 获取收藏列表
#[tauri::command]
fn get_favorites(state: tauri::State<AppState>) -> Result<Vec<db::FavoriteCity>, String> {
    state.db.get_favorites()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            // 初始化数据库，使用应用的数据目录
            let app_dir = app.path().app_data_dir()
                .map_err(|e| e.to_string())?;
            let db = Database::new(app_dir)
                .expect("数据库初始化失败");
            app.manage(AppState { db });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            greet,
            get_weather,
            add_favorite,       // ← 新注册
            remove_favorite,    // ← 新注册
            get_favorites,      // ← 新注册
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

### 3.3 前端收藏 UI（示意）

```typescript
// src/App.vue 中新增
import { invoke } from "@tauri-apps/api/core";

interface FavoriteCity {
  id: number;
  city: string;
  province: string;
}

const favorites = ref<FavoriteCity[]>([]);

async function loadFavorites() {
  favorites.value = await invoke("get_favorites");
}

async function addCurrentCity() {
  await invoke("add_favorite", {
    city: selectedCity.value,
    province: selectedProvince.value,
  });
  await loadFavorites();
}

async function removeFav(id: number) {
  await invoke("remove_favorite", { id });
  await loadFavorites();
}
```

再在模板里加一个"我的收藏"区域，用 `v-for` 渲染列表即可。

---

## 四、编译验证

```bash
# 1. 确认 Rust 编译通过
cd src-tauri && cargo check

# 2. 完整构建生成 HAP
cargo tauri ohos build

# 3. DevEcoStudio 部署到手机测试
```

---

## 五、为什么 bundled 能在鸿蒙上工作？

```
编译时
──────
rusqlite
  └── libsqlite3-sys
        └── sqlite3.c  ← 源码捆绑在 crate 里
        └── cc crate   ← 调用 C 编译器
                         编译成 .o 对象文件
                         静态链接进最终 .so

运行时
──────
鸿蒙手机加载 libtauri_demo_lib.so
  └── SQLite 的所有代码已经在 .so 里了
  └── 不需要系统提供 libsqlite3.so
```

**这就是静态链接的优势** — 不依赖目标平台是否安装了某个系统库。

---

## 六、常见问题 FAQ

### ❓ `bundled` 会使包体积变大多少？

SQLite 的 C 源码大约 **700KB**，压缩后 ~200KB，对最终 HAP 体积影响很小。

### ❓ 有没有完全纯 Rust 的 SQLite 替代？

有 —— **[Limbo](https://github.com/penberg/limbo)**、**[SQLPage](https://sql.ophir.dev/)**、**[Polars](https://www.pola.rs/)**（DataFrame，非 SQLite 但可做替代）。但 `rusqlite` + `bundled` 是目前最成熟、最稳定的方案。

### ❓ 其他数据库呢？

| 数据库 | Rust 客户端 | 鸿蒙适配方式 |
|--------|-----------|------------|
| SQLite | `rusqlite` | `bundled` |
| MySQL | `sqlx` | 需要编译时连 MySQL 服务器（纯 Rust 驱动） |
| PostgreSQL | `sqlx` / `tokio-postgres` | 纯 Rust 实现 |
| Redis | `redis-rs` | 纯 Rust 实现 |
| MongoDB | `mongodb` | 纯 Rust 实现 |

---

## 七、总结

```
添加一个带系统依赖的 Rust 库 → 鸿蒙
     │
     ├─ 有 bundled ？ → 开 bundled, 直接编译
     ├─ 有纯 Rust feature ？ → 开 feature
     └─ 都没有 → fork + patch（下篇讲）
```

`rusqlite` + `bundled` 是典型的**零代码改动、只改 features** 的适配方式，也是你适配其他 C 依赖库时应该优先尝试的方案。

---

> 📄 下一篇：[06-实战案例2-文件下载与图片处理.md](./06-实战案例2-文件下载与图片处理.md)

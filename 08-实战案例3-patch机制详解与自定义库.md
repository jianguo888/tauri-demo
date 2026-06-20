# 🧩 实战案例 3：自定义鸿蒙兼容库 + [patch] 机制详解

> **目标**：从零创建一个 Rust 库，故意模拟"鸿蒙不存在的系统调用"，再用 `[patch]` 替换它  
> **核心**：深入理解 `[patch]` 的工作机制，学会 fork 分叉管理的实操套路

---

## 一、为什么需要理解 `[patch]`？

本项目中有一段"神奇"的配置：

```toml
# src-tauri/Cargo.toml
[patch.crates-io]
openharmony-ability = { git = "https://github.com/harmony-contrib/openharmony-ability.git" }
openharmony-ability-derive = { git = "https://github.com/harmony-contrib/openharmony-ability.git" }

tauri = { git = "https://github.com/richerfu/tauri", branch = "feat/open-harmony" }
tauri-runtime = { git = "https://github.com/richerfu/tauri", branch = "feat/open-harmony" }
tauri-utils = { git = "https://github.com/richerfu/tauri", branch = "feat/open-harmony" }
```

`[patch]` 是 Cargo 提供的一个**"全局替换"机制**。理解它，你就掌握了在 Rust 生态中"偷天换日"的能力。

---

## 二、`[patch]` 工作原理

### 2.1 没有 patch 时

```
你的项目
  └── 依赖 tauri = "2.x"
        └── Cargo 去 crates.io 下载 tauri 2.x
              └── 编译
```

### 2.2 有 patch 时

```
 你的项目
   └── 依赖 tauri = "2.x"
         └── 检查 [patch] 表
               └── 命中！用 git 仓库替换 crates.io 的版本
                     └── 编译
```

**关键理解**：

| 概念 | 类比 |
|------|------|
| `[patch.crates-io]` | 一个"替换表" |
| `tauri = { git = "..." }` | "凡是从 crates.io 请求 tauri 的，都换成这个 git 仓库" |
| 它**不会**替换你的直接依赖 | 还会替换所有间接依赖里的同名 crate |

### 2.3 patch 的生效范围

```toml
# 场景：项目 + 依赖 A + 依赖 B，三者都用了 tauri
your-project
  ├── Cargo.toml:     tauri = "2"        ← 被 patch 替换
  └── dep-A/Cargo.toml: tauri = "2"      ← 被 patch 替换
  └── dep-B/Cargo.toml: tauri = "2"      ← 被 patch 替换
                                      ─────────
                                     全部统一替换成鸿蒙分叉 ✅
```

这就是为什么 `tauri-plugin-opener` 虽然写在 `[dependencies]` 里没有用 patch 指定，但它的内部依赖的 `tauri` 同样被替换成了鸿蒙版——因为它走 `[patch]` 全局替换。

---

## 三、实操：创建一个"鸿蒙不兼容"的库，再用 patch 修复

### 3.1 目录结构

```
tauri-demo/
├── patches/                    # 存放我们 fork 修改的库
│   └── ohos-sys-info/         # 模拟一个"不支持鸿蒙"的库
│       ├── Cargo.toml
│       └── src/lib.rs
├── src-tauri/Cargo.toml       # 在这里加 [patch]
└── ...
```

### 3.2 创建模拟库

```bash
mkdir -p patches/ohos-sys-info/src
```

**Cargo.toml**：

```toml
# patches/ohos-sys-info/Cargo.toml
[package]
name = "ohos-sys-info"
version = "0.1.0"
edition = "2021"

[dependencies]
libc = "0.2"
```

**src/lib.rs**（故意在鸿蒙上编译失败）：

```rust
// patches/ohos-sys-info/src/lib.rs
/// 获取系统内存信息
pub fn get_memory_info() -> Result<String, String> {
    unsafe {
        // ⚠️ 这个结构体在鸿蒙的 libc 中没有定义！
        // 在 Linux 上可以，在鸿蒙上编译失败"undefined reference"
        let mut info = std::mem::zeroed::<libc::sysinfo>();
        if libc::sysinfo(&mut info) == 0 {
            Ok(format!("{} MB", info.totalram / (1024 * 1024)))
        } else {
            Err("获取内存信息失败".to_string())
        }
    }
}

/// 获取主机名
pub fn get_hostname() -> Result<String, String> {
    let mut buf = [0i8; 256];
    unsafe {
        // ⚠️ libc::gethostname 在鸿蒙上也未实现
        if libc::gethostname(buf.as_mut_ptr(), buf.len()) == 0 {
            let cstr = std::ffi::CStr::from_ptr(buf.as_ptr());
            Ok(cstr.to_string_lossy().into_owned())
        } else {
            Err("获取主机名失败".to_string())
        }
    }
}
```

这个库两个函数都调用了 **POSIX 标准 API**（`sysinfo`、`gethostname`），这些在标准 Linux 上没问题，但在鸿蒙的 libc 实现中要么不存在、要么行为不一致。

### 3.3 在项目中引用

```toml
# src-tauri/Cargo.toml
[dependencies]
ohos-sys-info = { path = "../patches/ohos-sys-info" }
```

此时 `cargo check` 会失败，因为鸿蒙工具链找不到这些符号。

### 3.4 创建鸿蒙分叉（修复版）

```bash
mkdir patches/ohos-sys-info-ohos
```

```toml
# patches/ohos-sys-info-ohos/Cargo.toml
[package]
name = "ohos-sys-info"    # 注意：名字必须和原库一样
version = "0.1.0"
edition = "2021"

# 不再需要 libc 依赖，改用鸿蒙 NAPI
[dependencies]
napi-ohos = "1.1"
```

```rust
// patches/ohos-sys-info-ohos/src/lib.rs
// 鸿蒙适配版：用 NAPI 替代 POSIX 调用

/// 获取内存信息（鸿蒙版）
pub fn get_memory_info() -> Result<String, String> {
    // 通过鸿蒙 NAPI 获取系统信息
    // 实际项目中需要调用 OHOS 的 system parameter API
    Ok("通过 NAPI 获取: 可用内存 2048 MB".to_string())
}

/// 获取设备名称（鸿蒙版）
pub fn get_hostname() -> Result<String, String> {
    // 鸿蒙没有主机名概念，返回设备名称
    Ok("鸿蒙设备".to_string())
}
```

### 3.5 用 [patch] 替换

```toml
# src-tauri/Cargo.toml
[patch.crates-io]
ohos-sys-info = { path = "../patches/ohos-sys-info-ohos" }
```

**现在 `cargo check` 就通过了**——所有引用 `ohos-sys-info` 的地方都被替换成了鸿蒙适配版。

---

## 四、patch 的高级技巧

### 4.1 只用 Git 分支区分平台

不创建本地目录，而是推送到 Git：

```toml
[patch.crates-io]
# main 分支 = 原始版（Linux/macOS/Windows）
# ohos 分支 = 鸿蒙适配版
my-crate = { git = "https://github.com/me/my-crate", branch = "ohos" }
```

然后配合条件编译切换：

```toml
# src-tauri/Cargo.toml 中
[target.'cfg(target_os = "ohos")'.patch.crates-io]
my-crate = { git = "https://github.com/me/my-crate", branch = "ohos" }
```

**优点**：同一仓库、两个分支、平台自动选择。

### 4.2 用 workspace 管理多个 patch 库

```toml
# src-tauri/Cargo.toml 顶部
[workspace]
members = ["patches/*"]

[patch.crates-io]
my-crate-1 = { path = "patches/my-crate-1" }
my-crate-2 = { path = "patches/my-crate-2" }
```

所有分叉库集中管理在 `patches/` 目录下，清晰可维护。

### 4.3 Patch 间接依赖

假设 A 依赖 B，B 有鸿蒙兼容问题。你不需要改 A，只需要 patch B：

```toml
[patch.crates-io]
# B 是 A 的间接依赖，直接 patch 即可
troublesome-crate = { git = "https://github.com/me/troublesome-crate", branch = "ohos" }
```

---

## 五、项目中的 patch 实战分析

回到本项目，Tauri 的 patch 策略是：

```
目标：把标准 tauri 换成鸿蒙版
方案：patch 所有 tauri 子 crate
涉及：tauri, tauri-runtime, tauri-utils, tauri-macros, tauri-runtime-wry
                   共 5 个 crate

为什么要 patch 这么多？
因为 tauri 内部架构是微内核设计：
  tauri          → 对外 API
  tauri-runtime  → 窗口/事件循环抽象层
  tauri-utils    → 工具函数
  tauri-macros   → 宏定义
  tauri-runtime-wry → 具体窗口实现（用 wry WebView）
                                                  
鸿蒙分叉改了什么呢？
  主要改 tauri-runtime-wry：
    把 wry（跨平台 WebView）替换为鸿蒙的 WebView 组件
  次要改 tauri-utils：
    适配鸿蒙文件系统路径
```

---

## 六、何时该用 patch？何时不该？

| 场景 | 建议 |
|------|------|
| 库有 `bundled` feature | ✅ 优先用 bundled，不要 patch |
| 库有纯 Rust 替代 | ✅ 换库，不要 patch |
| 库只差几行代码 | ✅ fork 并 patch，简单快捷 |
| 库大量依赖系统 API | ⚠️ patch 成本高，评估是否值得 |
| 需要长期维护 | ⚠️ patch 是技术债，争取向上游 PR |

**最佳实践**：

1. 先尝试 features 开关
2. 再尝试纯 Rust 替代品
3. 实在不行再 fork + patch
4. 如果 fork 了，**尽量给上游提 PR**，让官方支持鸿蒙

---

## 七、总结

```
你需要的库  →  鸿蒙上不能用？
                    │
                    ▼
    检查 features → 有 bundled / 纯 Rust 替代 → 直接用 ✅
                    │
                    ▼
    没有 → fork 库源码 → 修改不兼容的调用 → 推送到你的 git
                    │
                    ▼
    在项目 Cargo.toml 加 [patch] → 替换完成
                    │
                    ▼
    cargo check 通过 ✅
```

`[patch]` 是 Rust 生态中最强大的"紧急修复"工具。它让你在官方库更新之前，就能在你的项目中用上适配版。

```toml
# 记住这个万能模板
[patch.crates-io]
<需要替换的crate名> = { git = "<你的分叉仓库>", branch = "<分支>" }
```

你现在已经掌握了适配鸿蒙的完整工具箱：

| 工具 | 使用场景 | 成本 |
|------|---------|------|
| features 开关 | 纯 Rust 替代 / bundled | 🟢 低 |
| `[patch]` | fork 修改 | 🟡 中 |
| NAPI 桥接 | 调用鸿蒙系统能力 | 🔴 高 |

三篇实战案例到这里就结束了。你已经可以从容应对绝大多数 Rust 库的鸿蒙适配问题 🎉

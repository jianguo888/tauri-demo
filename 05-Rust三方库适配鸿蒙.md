# 🦀 Rust 三方库如何适配鸿蒙平台？— 从本项目的实战经验谈起

> **阅读对象**：有 Rust 基础或对本项目的技术原理感兴趣的开发者  
> **目标**：理解 Rust 三方库在鸿蒙上"能跑 / 不能跑 / 怎么改"的判断方法和适配策略

---

## 一、一个现实的问题

你写了一个 Tauri + HarmonyOS 项目，想在 Rust 后端加一个新功能：

> _"加个图片处理吧，用 `image-rs` 压缩一下"_

于是你在 `Cargo.toml` 里加了：

```toml
image = "0.25"
```

然后 `cargo build`…… 编译失败，报错：

```
error: linking with cc failed: exit status: 1
cannot find -ljpeg
```

**为什么？** 因为鸿蒙系统上没有 `libjpeg` 这个系统库。而 `image-rs` 默认开启了 JPEG 支持，它依赖系统的 C 库。

这就是 Rust 三方库适配鸿蒙的核心矛盾：

> **鸿蒙不是 Linux。它有自己的 C 库、自己的文件系统、自己的网络栈。**

---

## 二、Rust 库的"血型分类"

从鸿蒙兼容性角度，Rust 第三方库可以分成三类：

### 🟢 Type A：纯 Rust 实现

```toml
serde       = "1"       # ✅ 纯 Rust，直接可用
serde_json  = "1"       # ✅ 纯 Rust，直接可用
regex       = "1"       # ✅ 纯 Rust，直接可用
```

特点：
- 代码里只有 Rust，**没有任何 C 库调用**
- 跨平台编译只需重新编译一次
- **零适配成本**

### 🟡 Type B：可配置系统依赖

```toml
# ❌ 默认配置（依赖 openssl，在鸿蒙上编译失败）
reqwest = "0.12"

# ✅ 换成纯 Rust 的 TLS 实现
reqwest = { version = "0.12", features = ["rustls-tls"], default-features = false }
```

特点：
- 提供了 `features` 开关，可以在纯 Rust 和系统依赖之间切换
- 需要检查文档找到 `rustls`、`bundled`、`native-tls` 等 feature
- **适配成本低**：换 feature 就行

### 🔴 Type C：硬依赖系统库

```toml
# 依赖 OpenSSL，鸿蒙上根本没有
openssl = "0.10"

# 依赖系统 SQLite
rusqlite = "0.32"  # 需要改 features = ["bundled"]
```

特点：
- 底层调用了目标平台的 C 库（`libc`、`libssl`、`libsqlite3`……）
- 有些提供 `bundled`（把 C 源码打包进编译），有些没有
- 如果既不提供纯 Rust 实现，也不提供 bundled，就必须 **fork 魔改**

---

## 三、从本项目看到的 4 种适配手段

本项目恰好是 Rust 适配鸿蒙的一个"活标本"，4 种适配手段全用上了。

---

### 🔧 手段 1：用纯 Rust 替代品（零成本适配）

**案例：`reqwest` + `rustls-tls`**

```toml
# Cargo.toml
reqwest = { version = "0.12", features = ["json", "rustls-tls"], default-features = false }
```

- 默认 `reqwest` 用 `native-tls` → 需要 OpenSSL → 鸿蒙上没有
- 改成 `rustls-tls` → 纯 Rust TLS 实现 → **零系统依赖，直接编译通过**

**⬇️ 可供参考的纯 Rust 替代品速查表**

| 需要做的事 | 系统库方案 | ❌ 问题 | 纯 Rust 替代 | ✅ |
|-----------|----------|--------|-------------|----|
| HTTPS 请求 | `reqwest` + `native-tls` | 要 OpenSSL | `reqwest` + `rustls-tls` | ✅ |
| 图片解码 | `image` 全 feature | 要 libjpeg/libpng | `image` 只开 png + pure Rust decoder | ✅ |
| 压缩/解压 | `flate2` | 要 libz | `flate2/rust_backend` | ✅ |
| XML 解析 | `quick-xml` + `libxml2` | 要 libxml2 | `quick-xml` | ✅ |
| 正则表达式 | `pcre2` | 要 libpcre | `regex` | ✅ |
| 数据库 | `rusqlite` 默认 | 要 libsqlite3 | `rusqlite/bundled` 或 `sqlparser` | ✅ |

**核心原则：先查有没有纯 Rust 替代品，这是成本最低的方案。**

---

### 🔧 手段 2：利用 `bundled` 特性（一起编译）

有些库虽然没有纯 Rust 实现，但提供了 **bundled 模式**：把 C 源码打包到一起，用 `cc` crate 编译，不依赖系统已安装的库。

**案例：`rusqlite`**

```toml
rusqlite = { version = "0.32", features = ["bundled"] }
```

`bundled` 会让编译时自动下载 SQLite 的 C 源码并一起编译成 `.o`，最终静态链接进最终产物。**对鸿蒙来说，相当于把依赖"内置"了**。

> 如果某个库有 `bundled` feature，这是第二优先选择。

---

### 🔧 手段 3：使用分叉（Fork） + `[patch]` 替换

**这是最重的手段，用于核心框架级别的适配。**

**案例：`tauri` 全家桶**

```toml
# 这不是官方 tauri 源，而是 @richerfu 维护的鸿蒙分叉
tauri = { git = "https://github.com/richerfu/tauri", branch = "feat/open-harmony" }
tauri-runtime = { git = "https://github.com/richerfu/tauri", branch = "feat/open-harmony" }
tauri-utils = { git = "https://github.com/richerfu/tauri", branch = "feat/open-harmony" }
tauri-macros = { git = "https://github.com/richerfu/tauri", branch = "feat/open-harmony" }
tauri-runtime-wry = { git = "https://github.com/richerfu/tauri", branch = "feat/open-harmony" }
```

这个分叉做了什么？

| 原始 tauri | 鸿蒙分叉 |
|-----------|---------|
| 用 Tao 创建原生窗口 | 改用鸿蒙 Ability 作为窗口 |
| 用 WRY 创建 WebView | 改用鸿蒙 WebView 组件 |
| 用 macOS/Windows/Linux 文件 API | 改用鸿蒙沙盒文件系统 |
| 用 POSIX 线程模型 | 改用鸿蒙线程模型 |

**但这里有个问题**：如果依赖树里多个 crate 都依赖了 `tauri`，它们可能引用不同版本。解决方案是 `[patch]` 机制：

```toml
[patch.crates-io]
tauri = { git = "https://github.com/richerfu/tauri", branch = "feat/open-harmony" }
tauri-runtime = { git = "https://github.com/richerfu/tauri", branch = "feat/open-harmony" }
```

`[patch]` 是 Cargo 的"全局替换表"——**整个依赖树中所有用到的指定 crate 版本，都统一替换成你指定的源**。这样就不会出现版本冲突。

> 什么时候需要 fork？
> - 库的底层大量依赖操作系统 API（窗口、文件、线程、进程）
> - 库没有提供 features 开关来切换平台实现
> - 你愿意承担**长期维护分叉的成本**

---

### 🔧 手段 4：通过 NAPI 桥接鸿蒙系统能力

有些场景——你想调用鸿蒙独有的系统能力，不是标准 POSIX 接口——上面的方法都不管用。这时候需要 **NAPI（Native API）**。

**案例：`napi-ohos`**

```toml
napi-ohos = { version = "1.1" }
napi-derive-ohos = "1.1"
```

这是鸿蒙官方的 **Native API 的 Rust 绑定**。它让你：

```rust
// 通过 NAPI 调用鸿蒙系统服务
// 例如：发送通知、获取设备信息、调用传感器……
```

NAPI 是 Rust 和鸿蒙系统之间的"官方桥梁"：

```
Rust 代码 ──→ napi-ohos ──→ 鸿蒙 NAPI (C API) ──→ 鸿蒙系统服务
```

> NAPI 桥接是最后的手段——当你需要调用"鸿蒙独有的系统能力"而非标准系统能力时才用。

---

## 四、适配策略决策树

当你考虑在项目中引入一个新的 Rust 库时，可以按这个顺序决策：

```
                    你想加一个 Rust 库
                            │
                            ▼
            ┌─── 它是纯 Rust 实现的吗？───┐
            │                            │
           YES                          NO
            │                            │
            ▼                            ▼
     ┌────────────────┐      ┌─────────────────────────┐
     │  直接加，完事   │      │ 它依赖了 C 系统库吗？     │
     │  (serde/regex) │      └─────────┬───────────────┘
     └────────────────┘                │
                                  YES  │           NO
                                   │   │  (依赖的是 std，
                                   │   │   一般能直接编译)
                                   │   ▼
                                   │  检查 features 文档
                                   │  ┌──────────────────────┐
                                   │  │ 有纯 Rust feature？  │──→ 开启它 ✅
                                   │  │ 有 bundled 模式？    │──→ 开启它 ✅
                                   │  │ 有鸿蒙 patch/分叉？  │──→ 引用分叉 ✅
                                   │  └──────────────────────┘
                                   │            │
                                   │      都没有？
                                   │            │
                                   ▼────────────┘
                                          │
                                          ▼
                             ┌────────────────────────┐
                             │ 评估工作量，决定是否     │
                             │ fork 源码做鸿蒙适配     │
                             │ 或者换别的库           │
                             └────────────────────────┘
```

---

## 五、本项目依赖适配速查

| 依赖 | 类型 | 适配方式 | 难度 |
|------|------|---------|------|
| `tauri` | **Fork** | `feat/open-harmony` 分叉 + `[patch]` | 🔴 高 |
| `serde` / `serde_json` | 纯 Rust | 直接加 | 🟢 无成本 |
| `reqwest` | **换 feature** | `default-features=false`, `rustls-tls` | 🟢 低 |
| `napi-ohos` | 专用鸿蒙版 | 直接用 | 🟡 中 |
| `napi-derive-ohos` | 专用鸿蒙版 | 直接用 | 🟡 中 |
| `tauri-plugin-opener` | 跟随 tauri | 随分叉走 | 🟢 低 |
| `serde_json` | 纯 Rust | 直接加 | 🟢 无成本 |
| `openharmony-ability` | Fork | `[patch]` 替换 | 🟡 中 |

---

## 六、写在最后

Rust + HarmonyOS 目前还是"前沿探索"阶段，很多库需要手动适配。但随着：

- 鸿蒙系统的 Rust 生态继续成熟
- 更多 crate 提供 `rustls`、`bundled` 等 feature 开关
- Tauri 的鸿蒙分叉持续维护

适配成本会越来越低。

### 给项目维护者 3 个建议

1. **把 `[patch]` 统一管理** — 所有分叉依赖集中放在 Cargo.toml 底部，方便升级
2. **建一个"已测试通过"的清单** — 记录每个库在鸿蒙上的可用状态和 feature 要求
3. **尽可能提 PR 给上游** — 把你需要的 feature 开关（如 `rustls-tls`）贡献回官方库，减少分叉依赖

---

> 🎉 至此你已经掌握了 Rust 三方库适配鸿蒙的完整知识体系。
> 以后遇到"这个库能在鸿蒙上用吗？"的问题，先走一遍决策树，就知道答案了。

# 📦 从代码到 HAP — 应用是怎么跑到鸿蒙手机上的？

> **阅读对象**：零基础，想知道"代码怎么变成手机上的 App"  
> **目标**：理解构建流程、Tauri 配置、以及 HAP 打包的来龙去脉

---

## 1. 一句话概括

```
你写的代码 (Vue + Rust)
     │
     ▼  【构建流程：一条命令】
     cargo tauri ohos build
     │
     ▼
entry-default-unsigned.hap  ← 鸿蒙安装包
     │
     ▼  【部署：DevEcoStudio】
     运行到鸿蒙手机上
```

---

## 2. 构建流程 —— 这条命令到底干了什么？

当你在终端执行：

```bash
cd src-tauri && cargo tauri ohos build
```

Tauri 会按顺序执行 **4 个步骤**：

```
Step 1: pnpm build
        ─────────────
        编译前端代码（Vue → 静态 HTML/CSS/JS）
        产物: dist/index.html, dist/assets/*.js

Step 2: cargo build --release
        ──────────────────────
        编译 Rust 后端代码（.rs → 动态链接库 .so）
        产物: target/release/libtauri_demo_lib.so

Step 3: 生成鸿蒙工程
        ──────────────
        Tauri 把前端产物 + Rust 动态库 +
        模板文件合并 → gen/ohos/ 目录
        产物: 完整的鸿蒙项目结构

Step 4: hvigor build
        ─────────────
        鸿蒙的构建工具把项目打包成 HAP
        产物: entry-default-unsigned.hap
```

---

## 3. Step 1：前端构建

### 触发

配置在 `src-tauri/tauri.conf.json` 中：

```json
{
  "build": {
    "beforeBuildCommand": "pnpm build",   // ← 构建前自动运行
    "frontendDist": "../dist"             // ← 产物目录
  }
}
```

### 实际运行

```bash
pnpm build
# 等价于 → vue-tsc --noEmit && vite build
```

两个子步骤：
1. **`vue-tsc --noEmit`** — 检查 TypeScript 类型，有错就停止
2. **`vite build`** — 把 Vue 源码打包成浏览器能识别的静态文件

### 产物

```
dist/
├── index.html               # 入口页面
├── assets/
│   ├── index-DV24ggAs.js    # 所有 JS 打包成一个文件（75KB）
│   └── index-yfKK-ms3.css   # 所有 CSS 打包成一个文件（7.6KB）
```

---

## 4. Step 2：Rust 后端构建

Rust 代码被编译成 **动态链接库**（`.so` 文件，Linux/OHOS 上的动态库格式）。

关键的编译配置在 `Cargo.toml` 中：

```toml
[lib]
crate-type = ["staticlib", "cdylib", "rlib"]
```

- `cdylib` — 生成 `.so` 动态库，供鸿蒙 App 加载
- `staticlib` — 生成 `.a` 静态库，供其他场景使用

因为依赖了 `tauri`（来自 `feat/open-harmony` 分支的定制版），编译时会下载这个分支的所有 RUST 源码一起编译。

---

## 5. Step 3：生成鸿蒙工程

这是最神奇的一步。Tauri 的 CLI 工具会自动创建一个完整的鸿蒙项目到：

```
src-tauri/gen/ohos/
├── build-profile.json5            # 鸿蒙构建配置
├── hvigor/                        # 鸿蒙构建工具配置
├── entry/
│   ├── build/default/outputs/     # ← 最终 HAP 产物
│   │   └── entry-default-unsigned.hap
│   ├── src/main/
│   │   ├── ets/
│   │   │   ├── entryability/
│   │   │   │   └── EntryAbility.ets    # 鸿蒙 Ability（应用入口）
│   │   │   └── webview/
│   │   │       └── DefaultWebview.ets  # WebView 组件，加载你的 Vue 页面
│   │   └── resources/                  # 静态资源
│   └── oh-package.json5               # 鸿蒙依赖
└── oh_modules/                       # 鸿蒙 SDK 模块
```

关键的理解点：

### 🔑 EntryAbility.ets — 应用的"启动器"

```typescript
// 鸿蒙侧的"main 函数"
export default class EntryAbility extends Ability {
  onCreate() {
    // 加载 Rust 动态库
    // 初始化 WebView
  }
  onForeground() {
    // App 切换到前台
  }
}
```

### 🔑 DefaultWebview.ets — 显示你的界面

这个文件创建了一个鸿蒙的 **WebView 组件**，加载了你前端的 `index.html`。本质上就是：
> 鸿蒙 App 里嵌了一个**没有地址栏的浏览器**，里面跑着你的 Vue 页面。

但正因为有了这层"壳"，你的网页可以：
- 调用手机硬件（摄像头、传感器…）
- 在应用列表里显示图标
- 申请系统权限
- 被进程管理

---

## 6. Step 4：hvigor 打包为 HAP

`hvigor` 是鸿蒙的构建工具（相当于 Android 的 Gradle）。它把：

```
├── Rust 编译出的 .so        →  libs/arm64-v8a/libtauri_demo_lib.so
├── 前端编译出的 dist/       →  assets/web/
├── 鸿蒙源码（.ets）         →  编译成 Ark 字节码
└── 配置文件                 →  合并到 module.json
```

全部压缩成一个 **HAP 包**：

```
entry-default-unsigned.hap    ← 这就是最终的 App 安装包
```

注意文件名里的 **unsigned**（未签名）。鸿蒙要求所有 App 必须经过数字签名才能安装到真机上。

---

## 7. tauri.conf.json — 总配置

```json
{
  "productName": "tauri-demo",
  "version": "0.1.0",
  "identifier": "com.ranger.tauri-demo",

  "build": {
    "beforeDevCommand": "pnpm dev",       // 开发模式：启动 Vite 开发服务器
    "devUrl": "http://localhost:1420",    // 开发模式：实时预览地址
    "beforeBuildCommand": "pnpm build",   // 生产构建：先运行 pnpm build
    "frontendDist": "../dist"             // 生产构建：前端产物位置
  },

  "app": {
    "windows": [{
      "title": "tauri-demo",
      "width": 800,
      "height": 600
    }],
    "security": {
      "csp": null                         // 内容安全策略（null=不限制）
    }
  },

  "bundle": {
    "active": true,
    "targets": "all",
    "icon": ["icons/32x32.png", ...]
  }
}
```

| 字段 | 含义 |
|------|------|
| `identifier` | App 唯一标识，像包名 |
| `beforeBuildCommand` | 每次构建前自动执行的命令 |
| `frontendDist` | 告知 Tauri："前端打包完的静态文件在这里" |
| `security.csp` | 安全策略，null 表示不限制 API 调用 |

---

## 8. 部署：在 DevEcoStudio 中运行

### 为什么要有 DevEcoStudio？

前面几步已经生成了 HAP，但它是 **未签名** 的。鸿蒙不允许安装未签名的应用（安全原因）。

DevEcoStudio 是华为官方的 IDE，它负责：
1. **配置签名** — 用你的开发者证书给 HAP 签名
2. **安装运行** — 通过 USB 或网络把 App 推送到手机上

### 操作步骤

```
1. 打开 DevEcoStudio
2. File → Open → 选择 src-tauri/gen/ohos
3. File → Project Structure → Signing Configs → 配置签名
4. 点击 ▶️ Run
```

### 也可以命令行签名（高级）

```bash
# 如果配置了签名，hvigor 在构建时自动签名
# 产物变为: entry-default-signed.hap
# 然后用 hdc 安装:
hdc install entry-default-signed.hap
```

---

## 9. 一个重要的概念：Tauri 的"壳"逻辑

```
你写的                Tauri 生成的              鸿蒙系统看到的
─────────            ────────────              ──────────────
Vue 页面  ──放进──→  WebView 组件  ────放进──→  EntryAbility
Rust 库   ──链接──→  .so 动态库    ────加载──→  System.LoadLibrary
                     │
                     └── 两者通过 Tauri 桥通信
```

Tauri 不是把 Vue 编译成鸿蒙原生代码，而是：
1. 把 Vue 页面**装在 WebView 里展示**
2. 把 Rust 代码**编译成 .so 库供鸿蒙加载**
3. 两者通过 Tauri 内部机制互相调用

这就是"混合开发" —— 用 Web 技术写界面，用原生能力做底层。

---

## 10. 总结

```
                           cargo tauri ohos build
                                   │
    ┌──────────────────────────────┼──────────────────────────────┐
    │                              │                              │
    ▼                              ▼                              ▼
pnpm build                   cargo build                 生成鸿蒙工程
(Vue → dist/)                (Rust → .so)                 + hvigor 打包
    │                              │                              │
    └──────────────────────────────┼──────────────────────────────┘
                                   ▼
                     entry-default-unsigned.hap
                                   │
                            DevEcoStudio 签名
                                   │
                                   ▼
                         你的鸿蒙手机上运行的 App 🎉
```

整个流程一句话：
> **写 Vue + Rust → Tauri 帮你编成鸿蒙 App → DevEcoStudio 签名 → 手机运行**

---

## 附：常见问题

### ❓ 为什么产物叫 "unsigned"？

HAP 包没有数字签名，无法直接安装到真机。你需要在 DevEcoStudio 中配置开发者签名证书。

### ❓ 每次改代码都要重新跑整个构建吗？

**只改前端** → 改完后重新运行 `cargo tauri ohos build`（前端耗时极短）
**只改后端 Rust** → 同上，Rust 增量编译很快
**改配置** → 同上

### ❓ gen/ohos 能不能手动修改？

**可以但不推荐**。每次 `build` 都会重新生成这个目录，你的手动修改会被覆盖。如果真的需要定制，改的是 Tauri 的模板源码。

---

> 🎉 至此你已经了解了这个 Tauri + HarmonyOS 项目的**全部核心知识**！
> 从架构到代码，从构建到部署，你现在可以自信地说："我懂 Tauri 鸿蒙开发了！"

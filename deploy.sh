#!/bin/bash
# deploy.sh — 一键编译 + 安装 + 启动鸿蒙应用
# 用法: ./deploy.sh [--debug]

set -e

# ============ 配置 ============
BUNDLE_NAME="com.ranger.tauri_demo"
ABILITY_NAME="EntryAbility"

# Tauri 项目路径
TAURI_DIR="src-tauri"
# HAP 输出路径（相对 TAURI_DIR）
HAP_OUTPUT="gen/ohos/entry/build/default/outputs/default"

# ============ 解析参数 ============
BUILD_MODE="release"
BUILD_FLAG=""
if [ "$1" == "--debug" ]; then
  BUILD_MODE="debug"
  BUILD_FLAG="-d"
fi

echo "========================================"
echo " 🚀 鸿蒙一键部署 ($BUILD_MODE)"
echo "========================================"

# 1. 编译 HAP
echo ""
echo "📦 Step 1/3: 编译 HAP..."
cd "$TAURI_DIR"
cargo tauri ohos build $BUILD_FLAG
cd ..

# 2. 查找 HAP 文件
echo ""
echo "📲 Step 2/3: 安装到设备..."
if [ "$BUILD_MODE" == "release" ]; then
  HAP_FILE="$TAURI_DIR/$HAP_OUTPUT/entry-default-signed.hap"
else
  HAP_FILE="$TAURI_DIR/$HAP_OUTPUT/entry-default-unsigned.hap"
fi

if [ ! -f "$HAP_FILE" ]; then
  echo "❌ 未找到 HAP 文件: $HAP_FILE"
  exit 1
fi

hdc install "$HAP_FILE"
echo "✅ 安装成功"

# 3. 启动应用
echo ""
echo "▶️  Step 3/3: 启动应用..."
hdc shell aa start -a "$ABILITY_NAME" -b "$BUNDLE_NAME"
echo "✅ 启动成功"

echo ""
echo "========================================"
echo " ✅ 部署完成！应用已在设备上运行"
echo "========================================"

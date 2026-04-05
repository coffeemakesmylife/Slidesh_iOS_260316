#!/bin/bash
# 构建并在 iPhone 17 Pro Max 模拟器上运行 Slidesh
# 用法：./scripts/run_sim.sh

set -e

WORKSPACE="Slidesh.xcworkspace"
SCHEME="Slidesh"
BUNDLE_ID="com.bublelele..Slidesh"
SIM_NAME="iPhone 17 Pro Max"
BUILD_DIR="/tmp/slidesh_build"

# 找到处于 Booted 状态的 iPhone 17 Pro Max，否则启动第一个
SIM_ID=$(xcrun simctl list devices available | grep "$SIM_NAME" | grep "Booted" | head -1 | grep -oE '[A-F0-9-]{36}')
if [ -z "$SIM_ID" ]; then
    echo "⏳ 启动 $SIM_NAME 模拟器..."
    SIM_ID=$(xcrun simctl list devices available | grep "$SIM_NAME" | head -1 | grep -oE '[A-F0-9-]{36}')
    xcrun simctl boot "$SIM_ID"
    open -a Simulator
    sleep 3
fi

echo "📱 目标模拟器：$SIM_NAME ($SIM_ID)"
echo "🔨 开始构建..."

# 构建
xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$SIM_ID" \
    -derivedDataPath "$BUILD_DIR" \
    -quiet \
    build 2>&1 | grep -E "error:|warning:|BUILD SUCCEEDED|BUILD FAILED" | grep -v "warning:" | tail -5

# 找到 .app 路径
APP_PATH=$(find "$BUILD_DIR" -name "Slidesh.app" -path "*/Debug-iphonesimulator/*" | head -1)
if [ -z "$APP_PATH" ]; then
    echo "❌ 找不到构建产物"
    exit 1
fi

echo "📦 安装到模拟器..."
xcrun simctl install "$SIM_ID" "$APP_PATH"

echo "🚀 启动 App..."
xcrun simctl launch "$SIM_ID" "$BUNDLE_ID"

# 确保 Simulator.app 在前台
open -a Simulator
echo "✅ 完成"

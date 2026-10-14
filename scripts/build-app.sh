#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
app_path="$project_dir/Flash 游戏库.app"
staging_path="$project_dir/.build/Flash 游戏库.app"
old_app="$project_dir/Flash 游戏测试台.app"

chromium_source="${CHROMIUM_APP_SOURCE:-/private/tmp/chromium-flash-poc/extracted/chrome-mac/Chromium.app}"
if [[ ! -x "$chromium_source/Contents/MacOS/Chromium" ]]; then
  if [[ -x "$app_path/Contents/Resources/Chromium.app/Contents/MacOS/Chromium" ]]; then
    chromium_source="$app_path/Contents/Resources/Chromium.app"
  elif [[ -x "$old_app/Contents/Resources/Chromium.app/Contents/MacOS/Chromium" ]]; then
    chromium_source="$old_app/Contents/Resources/Chromium.app"
  fi
fi
if [[ ! -x "$chromium_source/Contents/MacOS/Chromium" ]]; then
  print -u2 "找不到 Chromium 运行组件：$chromium_source"
  exit 1
fi

python3 "$project_dir/scripts/patch-clean-flash.py"
mkdir -p "$project_dir/.build"
rm -rf "$staging_path"
mkdir -p "$staging_path/Contents/MacOS" "$staging_path/Contents/Resources"
clang -fobjc-arc -Wall -Wextra -framework Cocoa \
  -o "$staging_path/Contents/MacOS/FlashGameLibraryApp" \
  "$project_dir/src/FlashGameLibraryApp.m"
cp "$project_dir/src/Info.plist" "$staging_path/Contents/Info.plist"
cp "$project_dir/resources/AppIcon.icns" "$staging_path/Contents/Resources/AppIcon.icns"
ditto "$chromium_source" "$staging_path/Contents/Resources/Chromium.app"
ditto "$project_dir/.build/flash-runtime.plugin" \
  "$staging_path/Contents/Resources/PepperFlashPlayer.plugin"
codesign --force --sign - "$staging_path"
codesign --verify "$staging_path"

if [[ -d "$app_path" ]]; then
  backup="$project_dir/.build/Flash 游戏库.previous.app"
  rm -rf "$backup"
  mv "$app_path" "$backup"
fi
mv "$staging_path" "$app_path"
print "已生成：$app_path"

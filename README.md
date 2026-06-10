# Capslox Basic Navigation

一个轻量的 macOS 实现，用 Karabiner-Elements 把 `Caps Lock` 当成临时功能键：

| Hotkey | Output |
| --- | --- |
| `Caps Lock + E` | Up |
| `Caps Lock + D` | Down |
| `Caps Lock + S` | Left |
| `Caps Lock + F` | Right |
| `Caps Lock + I` | Page Up |
| `Caps Lock + K` | Page Down |
| `Caps Lock + J` | Home |
| `Caps Lock + L` | End |

短按 `Caps Lock` 仍然切换大小写。

## 方案评估

macOS 上单纯用 shell 脚本不能长期拦截系统键盘事件，所以这里选择 Karabiner-Elements：

- 稳定性：高。Karabiner 是 macOS 上处理底层键盘映射的常用方案。
- 可维护性：高。规则是 JSON，脚本只负责安装和启用规则。
- 权限要求：需要 Karabiner-Elements，并授予 Input Monitoring 权限。
- 兼容性限制：某些 App 会自己拦截快捷键；密码输入、系统安全输入场景也可能影响热键行为。
- 功能范围：只实现你列出的基础导航，不包含 Capslox 的选择、删除、多剪贴板、窗口绑定等功能。

Capslox 官方文档里说明它把 `Caps Lock` 变成 modifier，并且默认 `Caps Lock + E/D/S/F` 分别是上下左右。本项目只复刻这部分，并把 `I/K/J/L` 自定义成 `PageUp/PageDown/Home/End`。

## 安装

先安装 Karabiner-Elements：

```sh
brew install --cask karabiner-elements
```

然后运行：

```sh
chmod +x ./install-macos-karabiner.sh
./install-macos-karabiner.sh
```

脚本会：

- 写入 complex modification 规则到 `~/.config/karabiner/assets/complex_modifications/capslox-basic-navigation.json`
- 备份并更新 `~/.config/karabiner/karabiner.json`
- 打开 Karabiner-Elements

如果不想让脚本自动改 `karabiner.json`，只安装规则文件：

```sh
./install-macos-karabiner.sh --asset-only
```

然后手动到 Karabiner-Elements > Complex Modifications > Add rule 启用 `Capslox Basic Navigation`。

## Modifier Keys 修复

如果你在 macOS System Settings 里把 `Control` 和 `Globe` 互换了，安装 Karabiner 后可能看起来“失效”。原因是 Karabiner 会通过自己的虚拟键盘重新发出事件，macOS 的 Modifier Keys 设置不一定作用在你截图里选中的 `Apple Internal Keyboard / Trackpad` 上。

如果只想交换 macOS 内置键盘的 `Fn/Globe` 和 `Control`，同时保留外接键盘自己的设置，运行：

```sh
./install-macos-karabiner.sh --swap-control-globe
```

这会：

- 清掉旧版脚本写入的 profile 级别 `Fn/Control` Simple Modifications
- 加入一条只匹配内置键盘的 complex modification：`device_if` / `is_built_in_keyboard: true`
- 在内置键盘上交换 `Fn/Globe` 和 `left_control`
- 不改外接键盘的 `right_option` / `fn` / `control` 等键位

不要把 `Fn/Globe` 和 `Control` 写成 Karabiner profile 级别的 Simple Modifications；profile 级别会影响所有当前和未来接入的外接键盘，可能导致外接键盘的 modifier 键位错乱。

## IQUNIX ZONEX75 外接键盘修复

如果 IQUNIX ZONEX75 在 Karabiner EventViewer 里表现为：

- 物理 `Right Opt` 输出 `right_command`
- 物理 `Right Ctrl` 输出 `right_option`
- 物理 `Fn` 输出 `keyboard_fn`，但 `Fn + C` 不能当作 `Control + C`

运行：

```sh
./install-macos-karabiner.sh --fix-iqunix-zonex75
```

这会加入一条只匹配 `vendor_id: 12815` / `product_id: 20754` 的 complex modification：

- `right_command` -> `right_option`
- `right_option` -> `right_control`
- `keyboard_fn` -> `right_control`

这条规则只作用于 IQUNIX ZONEX75，不影响内置键盘或其他外接键盘。

## 外接键盘失效（复合设备）修复

有些外接键盘（尤其是蓝牙模式）会把自己上报成「键盘 + 指针设备」的复合 HID 设备，例如 IQUNIX MQ80 蓝牙连接时是：

```json
{ "is_keyboard": true, "is_pointing_device": true, "vendor_id": 9306, "product_id": 33398 }
```

Karabiner 对任何带 `is_pointing_device: true` 的设备**默认关闭 "Modify events"**（避免误改鼠标），所以所有 complex modifications 在这类键盘上静默失效。日志特征是 `/var/log/karabiner/core_service.log` 里只有 `caps lock is found on ...`，没有后续的 `(grabbed)`。

安装脚本现在默认会通过 `karabiner_cli --list-connected-devices` 枚举当前连接的复合键盘（排除名字像 Mouse/Trackpad/Touchpad 的设备、虚拟设备和内置键盘），自动在选中 profile 的 `devices` 里写入 `ignore: false`。**新键盘接上后重跑一次脚本即可**：

```sh
./install-macos-karabiner.sh
```

如果不想要这个行为，加 `--no-enable-composite-keyboards`。如果某个键盘的 "Modify events" 是你在 GUI 里手动关掉的（`ignore: true`），脚本会保留你的选择并打印警告，不会强行覆盖。

## 注意

`Home` / `End` 在 macOS 上不是所有 App 都等同于“行首 / 行尾”。有些编辑器会把它们解释为“文档开头 / 文档结尾”。如果你想让 `Caps Lock + J/L` 更接近 macOS 常见的行首 / 行尾，可以把规则里的：

```json
{ "key_code": "home" }
{ "key_code": "end" }
```

改成：

```json
{ "key_code": "left_arrow", "modifiers": ["left_command"] }
{ "key_code": "right_arrow", "modifiers": ["left_command"] }
```

## 回滚

脚本每次自动更新 `karabiner.json` 前都会生成备份，例如：

```text
~/.config/karabiner/karabiner.json.20260608-091500.bak
```

要回滚，可以把备份复制回 `~/.config/karabiner/karabiner.json`，或在 Karabiner-Elements 的 Complex Modifications 页面删除 `Capslox Basic Navigation` 规则。

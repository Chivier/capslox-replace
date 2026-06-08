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

## Modifier Keys 互换

如果你在 macOS System Settings 里把 `Control` 和 `Globe` 互换了，安装 Karabiner 后可能看起来“失效”。原因是 Karabiner 会通过自己的虚拟键盘重新发出事件，macOS 的 Modifier Keys 设置不一定作用在你截图里选中的 `Apple Internal Keyboard / Trackpad` 上。

更稳的做法是把这个互换也写进 Karabiner：

```sh
./install-macos-karabiner.sh --swap-control-globe
```

这会在当前 Karabiner profile 里加入：

- `left_control` -> `keyboard_fn` (`Globe/Fn`)
- `keyboard_fn` (`Globe/Fn`) -> `left_control`

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

# 剩余窗口 XAML 迁移计划

> 目标：把 `Gui/` 下剩余的 ~40 个传统 AHK `Gui()` 窗口迁到 AHK-XAML（WPF），复用 MacroEditGui 迁移已建立的模式与桥接能力。

## 1. 现状盘点

已迁 XAML（17）：VarListenGui、TimingGui、CMDTipGui、CMDTipSettingGui、UIMacroGui、VarModifyGui、UIMacroPanelSettingGui、UIMacroSettingGui、ToolRecordSettingGui、ThemeSettingGui、SettingMgrGui、MenuMacroSettingGui、MenuWheelGlobalSettingGui、MenuWheelGui、MacroGraphGui、HotkeySettingGui、ConfigMergeGui、MacroEditGui（本次）。

辅助文件（非窗口，不迁）：TabItemUIUtil、ThankUIUtil、VerticalSlider、MacroEditModel。

### 传统窗口清单（按行数排序）

**① 宏编辑器子编辑器（26 个，MacroEditGui.SubGuiConfig，优先）**

| 文件 | 行数 | 复杂度 |
|---|---|---|
| KeyGui | 1210 | 高 |
| SearchProGui | 1316 | 高 |
| SearchGui | 573 | 中 |
| KeyCheckGui | 1113 | 高 |
| BGKeyGui | 1012 | 高 |
| ExVariableGui | 601 | 中 |
| RunGui | 510 | 中 |
| MMProGui | 507 | 中 |
| FileIOGui | 450 | 中 |
| CompareGui | 431 | 中（嵌套 MacroEditGui） |
| OperationSubGui | 410 | 中 |
| TextOpsGui | 405 | 中 |
| ArrayGui | 400 | 中 |
| VariableGui | 374 | 中 |
| ScreenShotGui | 369 | 中 |
| CompareProGui | 342 | 中 |
| CompareProEditItemGui | 336 | 中 |
| BGMouseGui | 335 | 中 |
| LoopGui | 329 | 中 |
| WindowManageGui | 278 | 中 |
| SubMacroGui | 277 | 中 |
| MouseMoveGui | 268 | 中 |
| RMTCMDGui | 244 | 低 |
| InputGui | 226 | 低 |
| OutputGui | 224 | 低 |
| OperationGui | 202 | 低 |
| IntervalGui | 156 | 低 |
| CommentGui | 112 | 低 |
| ExVariableEditGui | 194 | 低 |

**② 其他独立窗口**

| 文件 | 行数 | 复杂度 |
|---|---|---|
| TriggerKeyGui | 1392 | 高（触发键配置） |
| ReplaceKeyGui | 1031 | 高 |
| FrontInfoGui | 418 | 中 |
| UseExplainGui | 275 | 中 |
| ColorPanelGui | 225 | 中 |
| InputBtnGui | 168 | 低 |
| FreePasteGui | 168 | 低 |
| TargetGui | 143 | 低 |
| MacroSettingGui | 109 | 低 |
| EditHotkeyGui | 91 | 低 |
| WinRuleGui | 95 | 低 |
| CustomMsgBoxGui | 40 | 低 |
| ErrorMsgBoxGui | 76 | 低 |
| CustomInputGui | 77 | 低 |
| Main/UIUtil.ahk | 主窗口 | 高 |

## 2. 可复用模式（来自 MacroEditGui 迁移）

- **窗口壳**：`XAML_TEMPLATE` + `XAML_Generator`，标题栏 + 关闭按钮 + `WindowChrome`。参照 ThemeSettingGui / MacroEditGui 的 `_BuildAndShow`。
- **Owner 模态**：外部用 `SafeGuiFromHwnd(OwnerHwnd).Opt("+Disabled/-Disabled")`（`Main/GlobalUtil.ahk`，WPF Owner 用 `WinSetEnabled` 兜底）；原生 OwnerHwnd 传给 `XAMLHost(..., ownerHwnd)` + `Update("Window","NativeOwner",...)`。
- **动态列表/树**：静态控件绑事件 + 回调内 `ui.Query(name)` 取选中项；`AddXamlItem` 动态注入；勾选标记用命名元素按名改 Visibility（不整树重渲染）。
- **菜单**：按钮 + 隐藏 Border 上 ContextMenu（`Update(name,"IsOpen","True")`），注入 `_MenuItemSubmenuStyle`/`_ContextMenuScrollStyle`（子菜单必需）。
- **多行文本**：`LengthPrefix` 已修复 `\r\n` 转义，`ui.Query` 可安全读多行值。
- **拖拽**：窗口级 `PreviewMouseMove/Up` + 命中测试 + `state["DragCoords"]`（DIP 坐标）。
- **桥接新增命令**：`HitTest:x;y`、`IsOverTree:x;y`、`FirstVisibleLine`、`ScrollToLine`、双击 `Handled`、`ClickCount`。
- **坑**：`Grid` 无 FontSize（用 `TextElement.FontSize`）；ComboBox 需显式 `SelectedIndex`；TreeViewItem 需 `Background="Transparent"` 整行命中；引擎改 C# 后删 `%TEMP%\AhkWpf\ahk-xaml.dll` 强制重编译。
- **TextBox 大坑（KeyGui 实测）**：XAML 里给 TextBox 设 `.Text()` 或 `.Width()`（Grid 内）会使控件**失效/不可输入**；用 `MinWidth` 可输入但光标定位偏。**正确写法照抄 `ToolRecordSettingGui`**：`.Width(60).Height(24).MinHeight(24).VerticalContentAlignment("Center").Padding("4,0").TextAlignment("Center").FontSize(11)`（StackPanel 内、无 `.Text()`），初始值用 `Update("Text", …)` 在 Init 里设。
- **桥接新增**：`KeyCapture` 事件（控件聚焦时捕获任意键 → AHK 键名），Hotkey 输入控件用只读 TextBox + `OnEvent(name,"KeyCapture",…)` 接收。
- **KeyGui 已知差异**：HotkeyCon 手输键名（非按键捕获后的即时显示——捕获后写入 TextBox，点击确定后网格高亮）；按键悬停高亮跳过（桥接无通用 MouseEnter/MouseLeave）。

## 3. 分阶段计划

> 每阶段保持可运行，真机回归。按复杂度先小后大；先迁编辑器子编辑器（26 个）让编辑流程全 XAML。

### P1 小窗（≤250 行，建立模式）
- 消息框/输入类：CustomMsgBoxGui、ErrorMsgBoxGui、CustomInputGui、TargetGui、EditHotkeyGui、WinRuleGui、MacroSettingGui、FreePasteGui、InputBtnGui
- 简单子编辑器：IntervalGui、CommentGui、OutputGui、InputGui、RMTCMDGui、OperationGui、ExVariableEditGui
- **验收**：各窗打开/确定/取消/Owner 模态正常。

> **已迁（P1+P2-1+P2-2，22 个）**：IntervalGui、CommentGui、OutputGui、InputGui、RMTCMDGui、OperationGui、ExVariableEditGui、ExVariableGui、MacroSettingGui、EditHotkeyGui、WinRuleGui、CustomMsgBoxGui、ErrorMsgBoxGui、CustomInputGui、RunGui、MMProGui、MouseMoveGui、SubMacroGui、FileIOGui、TextOpsGui、ArrayGui、VariableGui（2026-08-14）。
> **特殊窗口暂缓**：FreePasteGui（粘贴浮窗）、InputBtnGui（运行时输入按钮条，无边框透明+回车/Esc 轮询）、TargetGui（取色目标选择器）——均为无边框置顶浮窗，与编辑器壳不通用，不迁。

### P2 中子编辑器（250-600 行）
- RunGui、MMProGui、FileIOGui、TextOpsGui、ArrayGui、VariableGui、ScreenShotGui、BGMouseGui、LoopGui、WindowManageGui、SubMacroGui、MouseMoveGui、OperationSubGui、CompareGui、CompareProGui、CompareProEditItemGui、ExVariableGui、SearchGui
- **验收**：与 MacroEditGui 联动（打开/回写/模态）回归。

### P3 大窗（>600 行）
- KeyGui（已迁 2026-08-15）、BGKeyGui（已迁 2026-08-15）、KeyCheckGui（已迁 2026-08-15）、ReplaceKeyGui（已迁 2026-08-15）、TriggerKeyGui（已迁 2026-08-15）、SearchProGui（已迁 2026-08-15，最复杂：图片/颜色/文本搜索+配置管理，屏幕级截图/取色/预览框沿用原生）
- **验收**：复杂逻辑窗口全部功能回归。

### P4 主窗口 + 收尾
- Main/UIUtil.ahk（主 UI，未迁——最大一次性迁移，见下「主窗口迁移说明」）、UseExplainGui（已迁 2026-08-15）、FrontInfoGui（已迁 2026-08-15）、ColorPanelGui（暂缓——无边框置顶取色放大镜浮窗，同 TargetGui 类）
- 更新迁移文档/记忆，清理诊断。

---

## 5. 主窗口迁移说明（单独一轮）

主窗口 `Main/UIUtil.ahk`(786) + `Gui/TabItemUIUtil.ahk`(1177) ≈ 2000 行，是应用壳，无法像子窗口那样分个迁（壳和宏列表共用 `AddTableControl`/`MainSoftData.MyGui`/`TabCtrl`/`UIControls`，拆半截=主界面打不开=不可运行）。

核心架构：宏列表（`LoadItemFold` 7 页）用原生绝对定位虚拟列表——`AddTableControl` 加原生控件 → `ItemConInfo` 记 `OriPosX/Y` → 增删/折叠时 `UpdatePos` 调 `Con.Move` 重排。迁 XAML 要改成 `ItemsControl` 行式列表（每行 ~13 控件：标题/触发键按钮/触发类型/备注/前台信息/启用禁用/折叠…），等同逻辑树卡片那次，但每行控件多一个量级。

分两阶段（每阶段回归）：
1. 壳 + 静态标签页（左操作栏、TabControl、工具/设置/帮助/打赏/感谢 5 页）+ `AddTableControl` 适配器。
2. 宏列表 7 页改成 XAML 行式列表。

## 6. 最终迁移进度（截至 2026-08-15）

- **P1+P2**：22 个窗口 ✅
- **P3**：KeyGui、BGKeyGui、KeyCheckGui、ReplaceKeyGui、TriggerKeyGui、SearchProGui 全部 ✅（键位网格 4 个 + 触发键 + 图片搜索）
- **P4**：FrontInfoGui、UseExplainGui ✅；ColorPanelGui 暂缓（屏幕级放大镜浮窗）；Main/UIUtil.ahk 主窗口已迁（2026-08-15 编码完成，待真机回归，见 `Main/MainWindowXaml.ahk`）

**本次会话其余产出**：逻辑树卡片式扁平列表重写（增量更新 + ListBox 虚拟化滚动修复），见 `Web/逻辑树卡片式重写方案.md`。

## 4. 风险与注意

- 子编辑器被 MacroEditGui 实例化并设置 `SureBtnAction/OwnerHwnd/ParentTile`——**公开接口必须保持**（`ShowGui(cmd, showSaveBtn?)`、`SureBtnAction`、`OwnerHwnd`、`ParentTile`）。
- 嵌套 MacroEditGui 的窗口（CompareGui/SearchGui/LoopGui 等）已按 XAML 实例化，迁移本身不破坏嵌套调用。
- 每个窗口迁移前先读通 `Init/ShowGui/OnSureBtnClick` 主流程，把数据读写抽象到适配器/模型。
- C# 桥接改动影响全局，尽量只加不改；每批改完真机回归 + `AhkWpfError.log`。

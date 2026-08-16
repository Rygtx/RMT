# MacroEditGui XAML 迁移方案

> 目标：将传统 AHK `Gui()` 实现的主宏指令编辑器 `Gui\MacroEditGui.ahk`（2432 行）迁移到 AHK-XAML（WPF）技术栈，与 ThemeSettingGui / UIMacroGui / MacroGraphGui 等已迁移窗口保持一致。

---

## 1. 现状分析

### 1.1 文件规模与职责

| 部分 | 行数区间 | 内容 |
|---|---|---|
| 构造 / 指令配置 / 子编辑器注册 | 30–144 | `InitCommandConfigs` `InitSubGuiConfigs` `InitSubGui`，26 种子指令编辑器（SubGuiMap） |
| 窗口构建 | 146–365 | `ShowGui` `AddGui` `AddIconBtn` `InitGuiMenu`，左侧指令面板、顶部工具条、右侧树/文本区、底部按钮、菜单栏 |
| 初始化 / 文本模式 | 367–511 | `Init` `Backspace` `ClearStr` `OnChangeEditMode` `GetMacroStr` `InitMacroText` |
| 右键菜单 / 菜单处理 | 513–954 | `ShowContextMenu` `MenuHandler` `ContentMenuHandler`，含插入子菜单、跳过/调试起点 |
| 调试（F5/F6/⭐/→） | 956–1103 | `ResetDebugState` `MarkCurrentPosition` `AdvanceToNext` `FindDebugStartItem` |
| 树构建 / 渲染 | 1105–1234 | `InitTreeView` `RefreshTree` `TreeAddBranch` `TreeAddSubTree` `TreeAddControl` |
| 树操作（增删改插移） | 1235–1833 | `OnOpenSubGui` `OnAddCmd` `OnModifyCmd` `OnPreInsertCmd` `OnNextInsertCmd` `OnDeleteCmd` `MoveTreeViewItem` 等 |
| 序列化 / 持久化 | 1835–2030 | `GetTreeMacroStr` `SaveCommandData` `GetItemNumber` |
| 多选复制 | 1849–1955 | `SetMultiSelected` `ToggleMultiSelection` `SelectMultiRange` `GetMultiSelectedItems` |
| 拖拽（WM_LBUTTONDOWN） | 2032–2244 | `_OnLButtonDown` 手写拖拽：左面板拖入树、树内移动、插入位置提示 |
| 自定义绘制 / 命中测试 | 2246–2446 | `_OnNotify`（NM_CUSTOMDRAW 多选高亮）`TreeViewHitTest` `GetItemRect` `IsContainerNode` `MoveTreeViewItem` `IsDescendantOrSelf` |

### 1.2 窗口结构（AddGui）

```
主窗口 945×570，无系统标题栏（Owner 可配）
├─ 左侧「指令选项」GroupBox（x5 y10 w205 h530）
│    └─ 13×2 网格：26 个图标按钮（图标16px + 按钮75×30），点击=追加，拖拽=插入
├─ 顶部工具条
│    ├─ 编辑模式 DropDownList（逻辑树 / 文本）
│    ├─ 指令录制 CheckBox + 热键只读框
│    └─ 图形节点 Button（切 MacroGraphGui）
├─ 「当前宏指令」区
│    ├─ 全部展开 / 全部折叠 Button
│    ├─ TreeView（+Check，710×435）：逻辑树模式
│    └─ Edit：文本模式（隐藏）
└─ 底部按钮行：退格 / 清空指令 / 确定 / 应用并保存
```

### 1.3 核心耦合点

1. **全部树逻辑直接调用原生 TreeView API**：`Add/Delete/Modify/GetText/GetParent/GetChild/GetNext/GetPrev`，itemID 是 `HTREEITEM` 句柄。约 60% 代码（1800+ 行）与原生 TreeView 强耦合。
2. **拖拽**：`OnMessage(0x0201)` 拦截 `WM_LBUTTONDOWN`，`SetCapture` + `TVM_SETINSERTMARK`(0x111A) + `TVM_SELECTITEM`(0x110B) 做插入位置提示；`TreeViewHitTest` 用 `TVM_HITTEST`(0x1111) 自绘命中。
3. **多选**：`+Check` 用 Check 状态当多选标记，`_OnNotify` 用 `NM_CUSTOMDRAW` 把选中行染蓝底白字。
4. **图标**：`IL_Create` + `IL_Add` 图片列表，`GetCmdIconStr` 返回 `"IconN"`。
5. **调试标记**：⭐/🚫/→/⎖ 前缀编码进节点文字，运行时改文字。
6. **模态**：`OwnerHwnd` + `GuiFromHwnd(Owner).Opt("+Disabled/-Disabled")`。

### 1.4 外部调用面（迁移后必须兼容）

| 调用方 | 用法 | 迁移处理 |
|---|---|---|
| `GlobalUtil.ahk:85` | `global MyMacroGui := MacroEditGui()` | 保留单例，或改静态 instances Map |
| `CompareGui / SearchGui / LoopGui / ScreenShotGui / CompareProEditItemGui / TabItemUIUtil` | 各自 `MacroGui := MacroEditGui()`，设置 `.ParentTile` `.OwnerHwnd` `.SureBtnAction` 后 `.ShowGui(macro, false)` | 接口签名不变即可 |
| `RecordUtil.ahk:596-622, 802-841` | `MainSoftData.MacroEditGui.GetMacroStr()` / `.InitTreeView()` / `.InitMacroText()` | 需保持方法名与语义 |
| `VarListenGui.ahk:235-241` | `MainSoftData.MacroEditGui.Gui`（当 WinTitle/取 style）、`.ToolMenu.Uncheck()` | **需改**：`.Gui` 将变为 XAMLHost，改取 `wpfHwnd`；`.ToolMenu` 是 WPF Menu，无 `Uncheck`，改用 MenuItem 的 `IsChecked` |

> 关键：外部只依赖 `.ShowGui / .GetMacroStr / .InitTreeView / .InitMacroText / .SureBtnAction / .ParentTile / .OwnerHwnd`。这些保持稳定，迁移即可做到对调用方透明（除 VarListenGui 两处）。

---

## 2. XAML 桥接能力盘点

### 2.1 可用命令（C# bridge `XAML_AHK_Bridge.cs`）

| 命令 | 说明 |
|---|---|
| `ui.Update(name, "AddXamlItem", xamlStr)` | 向 ItemsControl（TreeView/TreeViewItem/ListBox）注入 `XamlReader.Parse` 的原始 XAML，自动 `RegisterName` 命名元素 |
| `ui.Update(name, "ClearItems", "")` | 清空 ItemsControl |
| `ui.Update(name, "SelectByTag", tag)` | **TreeView 专用**：按 `Tag` 递归查找 TreeViewItem，自动展开路径并选中（含 `ScrollIntoView`） |
| `ui.Update(name, prop, value)` | 通用属性写入；`Window.Close` 走 PostMessage 防死锁 |
| `ui.Update(name, "BindEvent", "Click")` | 动态注入元素后绑定事件 |
| `ui.OnEvent(name, eventName, cb)` + `ui.Track(name)` | 事件注册 |
| `ui.BatchUpdate(数组)` | 批量写入 |

### 2.2 动态树 / 列表模式（参考 `XAML_DevTools.ahk` / `XAML_Components.ahk`）

```ahk
; 每次重建：ClearItems 后逐层 AddXamlItem
this.ui.Update("MacroTree", "ClearItems", "")
for node in nodes
    this.ui.Update("MacroTree", "AddXamlItem", BuildTreeItemXaml(node))
; 节点重选中/展开
this.ui.Update("MacroTree", "SelectByTag", node.id)
```

`BuildTreeItemXaml` 输出 `<TreeViewItem xmlns="..." Tag="n1.2" Header="…" IsExpanded="…">`，Header 可用 `<StackPanel Orientation="Horizontal"><Image/><TextBlock/></StackPanel>` 放图标+文字；若需 CheckBox 多选，Header 内置 `<CheckBox Name="chk_n1.2" IsChecked="…"/>`。

> 树每次变更采用**全量重建**（宏条数有限，千条级内 WPF 重建可接受），`SelectByTag` 负责重建后恢复选中。这比增量增删 WPF 节点简单可靠得多。

---

## 3. 目标架构

### 3.1 AHK 侧节点数据模型

引入 `MacroEditNode`，取代对原生 TreeView 句柄的依赖：

```ahk
class MacroEditNode {
    id := ""            ; 稳定 id，如 "n1" / "n1.2" / "n1.2.3"
    cmdStr := ""        ; 原始指令串（含 ⭐/🚫/⎖ 前缀）
    display := ""       ; FormatCmdJoyDisplay 后的显示串
    icon := ""          ; 图标文件路径
    parent := ""        ; 父节点（""=根）
    children := []      ; 子节点数组
    checked := false    ; 多选标记
    expanded := false   ; 展开状态
    container := false  ; 真/假/循环体/条件 容器节点
}
```

根节点数组 `this.Nodes := []`。原生 TreeView 调用 → 节点数组操作：

| 原生 | 节点模型 |
|---|---|
| `TV.Add(text, parent, seq)` | 构造 MacroEditNode，插入 `parent.children` 指定位置 |
| `TV.GetText(id)` | `node.cmdStr / display` |
| `TV.GetParent/GetChild/GetNext/GetPrev` | `node.parent / children / 兄弟索引` |
| `TV.Modify(id, "Delete")` | `RemoveNode(id)` |
| `TV.GetCount` | 递归计数 |
| `IL_Add / "IconN"` | `Image Source="Images\Soft\xx.png"` 直接嵌入 |

所有遍历逻辑（`GetTreeMacroStr`、`GetItemNumber`、`TreeExpand`、`FindDebugStartItem`、`_CollectCheckedItems`）改为在节点数组上递归，语义不变。

### 3.2 视图层策略

- 主窗口 = `XAML_TEMPLATE` + `XAML_Generator` 构建（同 ThemeSettingGui）。
- 树的唯一真实来源是 `this.Nodes`；任何变更 → `RenderTree()` 全量重建 → `SelectByTag` 恢复选中/展开。
- 文本模式用 WPF `TextBox`，与现有逻辑兼容。
- 实例管理改用 ThemeSettingGui 的 `static instances Map` 模式（开→建实例、关→删除、失效→重建）。

### 3.3 控件映射表

| 现状 | XAML/WPF |
|---|---|
| `Gui(, title)` + 自绘标题栏 | `XAMLHost(XAML_TEMPLATE)` + `WindowChrome.CaptionHeight`（DragArea 标题栏） |
| `GroupBox` 指令选项 | WPF `GroupBox`（含默认样式注入，同 ThemeSettingGui） |
| `Picture` + `Button` 图标按钮 | `Button` + Header `<StackPanel><Image/><TextBlock/></StackPanel>`；点击事件 + 拖拽源 |
| `DropDownList` | WPF `ComboBox` |
| `CheckBox` | WPF `CheckBox` |
| `Edit`（文本模式） | WPF `TextBox` |
| `TreeView +Check` | WPF `TreeView`，TreeViewItem Header 内置 CheckBox |
| `IL_Create/IL_Add/IconN` | Header 内 `<Image Source="…"/>` |
| 右键 `Menu()` | WPF `ContextMenu`（动态项仍需每项命名 + BindEvent） |
| `MenuBar()` | WPF `Menu` / `MenuItem`（`IsCheckable` 实现变量监视勾选） |
| `OnMessage(0x0201)` 拖拽 | WPF `PreviewMouseLeftButtonDown` + `DoDragDrop` |
| `_OnNotify` NM_CUSTOMDRAW 高亮 | TreeViewItem Style Trigger（`IsSelected` / CheckBox 状态 / Tag 前缀） |
| `MsgBox(..., "Owner hwnd")` | `XAML_Dialog`（或保留原生 MsgBox + Owner） |
| F5/F6/Delete | `WinHotkey.Register` 继续用 WPF hwnd 注册（不变） |

---

## 4. 分阶段迁移计划

> ✅ **全部完成（2026-08-14）**，已真机回归通过：F5/F6 调试、变量监视、指令显示、图形节点、指令录制、双击编辑、右键菜单、多选、拖拽、子编辑器模态。

### P1 窗口壳 + 静态布局（替换 AddGui / AddIconBtn / InitGuiMenu）✅

- 建立 `MacroEditGui` 的 XAML 构建方法 `_BuildAndShow()`（参照 ThemeSettingGui 模板），布局复刻 1.2 结构。
- 左侧 26 个指令按钮：数据驱动 `SubGuiConfig` 生成，每按钮 Header = Image+Text，Name=`CmdBtn_<name>`，Click → `OnOpenSubGui(gui, 1)`。
- 顶部工具条、底部按钮（退格/清空/确定/应用并保存）、菜单栏（调试/工具）全部迁到 XAML。
- 替换 `this.Gui` 为 `this.ui`（XAMLHost），暴露兼容属性：`Gui`（= ui，若外部用到则改）、`wpfHwnd`。
- **验收**：窗口打开、左面板按钮可用（弹出子编辑器）、底部按钮、菜单项可用；树/文本区先渲染为空占位。

### P2 文本模式（替换 InitMacroText / GetMacroStr 的 Edit 分支）✅

- WPF `TextBox`（Name=`MacroText`），读 `TextBox.Text`、写回、`退格` 用 `SendMessage` 保留滚动位置逻辑照搬（0xCE/0xB6 在 WPF TextBox 上无效，改用 `SelectionStart` + `ScrollToVerticalOffset`，或直接简化：文本模式退格直接删末尾行）。
- **验收**：文本模式下增删改读、编辑模式切换、录制追加可用。

### P3 节点数据模型 + 树渲染（替换 InitTreeView / TreeAddBranch / 展开折叠）✅
> 实现差异：用 `MacroTreeAdapter`（`Gui/MacroEditModel.ahk`）实现原生 TreeView API 子集，逻辑层 1800 行原样保留，未逐行重写。

- 实现 `MacroEditNode`、`BuildTree(node, macroStr)` 把宏串解析成节点树、`RenderTree()`（ClearItems + AddXamlItem 递归）+ `SelectByTag` 恢复。
- 迁移 `TreeExpand / ExpandAll / CollapseAll / RefreshTree`（重建节点子树）。
- 保留 `TreeAddControl` 的 ⎖ 控制项（渲染成只读行）。
- **验收**：打开宏内容树可见，图标正确，展开/折叠/全部展开/折叠可用，⭐/🚫/⎖ 前缀显示正确。

### P4 树操作 + 持久化（工作量大头）✅
> 经适配器原样复用，未逐行迁移。

- 把 `OnAddCmd / OnModifyCmd / OnPreInsertCmd / OnNextInsertCmd / OnSubNodeAddCmd / OnSubNodeEdit / OnSwitchCmd / OnPreMoveCmd / OnNextMoveCmd / MoveTreeViewItem` 从原生 TV 调用改为节点数组操作，变更后 `RenderTree()` + 选中恢复。
- 迁移 `GetTreeMacroStr`（递归节点）`GetItemNumber`（按 parent.children 索引）`GetNthChildItem / GetNthCommandChild`。
- `SaveCommandData` 不变（纯数据持久化，不依赖控件）。
- **验收**：增删改插移、退格、清空、粘贴多选，均可正确刷新并落盘。

### P5 选择 / 多选 / 右键菜单 / 调试 ✅
> 实现差异：多选不渲染 CheckBox，改渲染蓝底 ✓ 标记（节点 `checked` 状态）；左/右键事件绑在静态 TreeView，用延迟后 `Query("MacroTree")` 取选中项，避免动态重建项的事件绑定丢失。

- 选择：WPF TreeView `SelectedItemChanged` → 映射回节点 id；`SelectByTag` 重建后恢复。
- 多选：Header CheckBox `Checked/Unchecked` 维护 `this.MultiSelectItems`（node id 集合），保留同层约束；`_OnNotify` 高亮删除，改为 TreeViewItem Style 依据 checked 变蓝底白字。
- 右键菜单：`ContextMenu` 重建（编辑/跳过/调试起点/插入指令子菜单/复制/粘贴/删除），`Opening` 时按当前节点文字动态改菜单文案（同现有 Skip/Debug 逻辑）。
- 调试：⭐/🚫/→/⎖ 前缀读写迁移到节点 `cmdStr`；`MarkCurrentPosition / ClearCurrentPosition / AdvanceToNext / FindDebugStartItem` 改为节点遍历，渲染仍走文字前缀。
- **验收**：多选复制/删除、Shift/Ctrl 选择、右键全部操作、F5/F6/Delete 与调试高亮与现状一致。

### P6 拖拽（最难点）✅
> 实现差异：未用 WPF `DoDragDrop`（bridge 不支持自定义数据/命中测试）。改为窗口级 `PreviewMouseMove/Up` + 屏幕坐标阈值的手动拖拽。左面板拖入=追加/插入选中节点后/内部；树内移动=先选目标再拖源。插入线提示为简化版（ToolTip），无 TVM_SETINSERTMARK 等价物。

- 左面板按钮 → 树：`PreviewMouseLeftButtonDown` 延迟判定，`DoDragDrop` 携带 `{cmdStr, icon}`；树侧 `DragOver` 判定插入目标与模式（上/下/内），首版用 Drop 事件 + `Tag` 定位；插入位置提示先简化（目标行高亮/下划线），不做 TVM_SETINSERTMARK 等价物。
- 树内移动：`DoDragDrop` 携带 `nodeId`，Drop 时先删后插（复用 MoveTreeViewItem 节点版）。
- **验收**：左面板拖入树追加/插入、树内移动、不可移动位置（容器内/自身后代）拦截，与现状行为一致。

### P7 子编辑器联动 + 外部兼容 + 回归 ✅
> 新增 `SafeGuiFromHwnd`（Main/GlobalUtil.ahk）：原生子编辑器对 WPF Owner 的 `GuiFromHwnd(...).Opt("+Disabled")` 改为 `WinSetEnabled` 兜底，批量替换 33 个 Gui 文件约 100 处调用，模态行为保留。

- 模态 Owner：`this.OwnerHwnd`（原生 hwnd）传给 `XAMLHost(…, …, ownerHwnd)` 或 `Update("Window","NativeOwner",…)`；替代 `GuiFromHwnd(Owner).Opt("+Disabled/-Disabled")` 的模态方案（WPF 用 ShowDialog 语义或 Owner + 手动 Disable）。
- 修 `VarListenGui.ahk`：`MainSoftData.MacroEditGui.Gui` → `wpfHwnd`；`ToolMenu.Uncheck` → 菜单项 `IsChecked` 读写。
- `SubMacroEditGui`（嵌套宏编辑器）本身也要走同一 XAML 类，递归调用不受影响。
- **验收**：CompareGui/SearchGui/LoopGui 等嵌套调用、RecordUtil 录制写入、指令显示联动全部回归通过。

---

## 5. 风险与决策

1. **拖拽插入位置提示（高）**：WPF 无 `TVM_SETINSERTMARK` 对应物，需要自定义 Adorner/行样式模拟"上/下/内"插入线。**决策**：P6 首版做简化版（目标行高亮 + ToolTip 文字提示），位置精确性后续用 Adorner 补。`ponytail: 简化插入指示器，后续加 Adorner`
2. **全量重建 vs 增量（中）**：每次变更 `ClearItems` + 全量 AddXamlItem。宏体量千条内无感；若未来超大宏出现卡顿，再改增量。
3. **原生窗口语义丢失（中）**：`Gui.Hwnd`、`WinGetStyle`、`WinActive("ahk_id "…)`、`SetCapture` 等对 WPF hwnd 的假设要逐一核对。WPF 窗口是真 HWND，WinGetStyle/WinActive 可用；`SetCapture` 拖拽逻辑整体替换为 WPF 事件。
4. **外部引用（低）**：仅 VarListenGui 两处需改动，其余接口保持稳定。
5. **测试手段（高）**：AHK-XAML 依赖 `ahk-xaml.dll` + CLR 引擎，无法静态验证；每阶段必须真机双击 `RMT.ahk` 人工回归。开发期可 `XamlUiDiag` 开诊断日志。
6. **主题/字体**：沿用 `ApplyXamlTheme(ui, theme)` 与 `MainSoftData.FontType` 注入（同 ThemeSettingGui 130-132 行做法）。

---

## 6. 验收标准

- 窗口外观/交互与现有版一致（布局、图标、右键菜单、调试高亮）。
- 逻辑树模式全部操作回归：增删改插移、多选复制/删除、Shift/Ctrl 选择、拖拽、展开折叠、调试（F5/F6/⭐/→/终止）。
- 文本模式回归：编辑、切换、录制。
- 嵌套调用（Compare/Search/Loop/ScreenShot/IfPro）与录制联动（RecordUtil）回归。
- 主题切换（明/暗）、DPI 缩放、模态 Owner 行为正常。

---

## 7. 最终状态与已知差异

功能与原版**已对齐**（经真机回归）。为对齐这些行为，给 C# 桥接（`lib/dep/XAML_AHK_Bridge.cs`）新增了命令：

| 新增 | 用途 |
|---|---|
| `Query(...>HitTest:x;y)` | 命中测试任意控件 → 树条目 `Tag|top/bottom|isExpander`；行间/行空白按 Y 回退命中最近行 |
| `Query(...>IsOverTree:x;y)` | 释放点是否在树上（拖出树即取消） |
| `Query(...>FirstVisibleLine)` / `Update(...ScrollToLine)` | 文本模式退格保留滚动位置 |
| `LengthPrefix` 转义 `\r\n` | 修复多行值（如宏文本）读回被 `\n` 截断 |
| `PreviewMouseLeftButtonDown` 双击置 Handled | 双击指令打开编辑器，不再展开/折叠；箭头双击正常切换 |

**剩余差异（均为视觉细节，不影响功能）**：
1. **拖拽无视觉插入线**：只有 ToolTip 文字提示（插入 X 上方/下方/内部），无 `TVM_SETINSERTMARK` 行间指示线。要补需 WPF Adorner。
2. **多选标记**：原生每项有复选框框，XAML 只有选中项显示蓝 ✓。
3. **折叠后模型不同步**：点箭头折叠只改 WPF，模型 `node.expanded` 未同步，后续增删触发重建时该分支可能还原展开。要同步需捕获 Expanded/Collapsed 事件（有竞态风险，暂缓）。
4. **树选中高亮 / 滚动条**：WPF 默认样式 vs 原生系统样式，细微视觉差。

**其余 45 个传统窗口**尚未迁移（KeyGui/LoopGui/RunGui/CompareGui 等），可复用本文档的适配器/命中测试/菜单/拖拽模式。

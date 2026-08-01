#Requires AutoHotkey v2.0

; =============================================================================
; AppThemeUtil — 统一主题颜色（通用窗口 / 轮盘 / 界面浮窗 / 指令显示等）
;
; 存储：MainSettings.ini [ThemeColors]
; 运行时：同步到 MainSoftData.ThemeColors，以及各消费字段（UIPanel* / CMD*）
; 通用窗口色：经 ApplyXamlTheme(..., useAppWinTheme:=true) 覆盖到 XAML Resource
;
; ---------- 扩展约定（增删改颜色 / 预设时请遵守）----------
; 1. 新增颜色项：
;    - 在 ColorDefs 增加 {Key, Group, Label}
;    - 至少在默认主题（DefaultThemeKey）Preset 上写上同名属性；其它预设建议一并补齐
;    - 若该色需驱动运行时字段，在 ApplyToRuntime / ApplyWinThemeToXaml 增加映射
;    - 主题设置 UI 按 ColorDefs 的 Group 自动排布，一般不必改 ThemeSettingGui
; 2. 删除颜色项：从 ColorDefs（及各 Preset 属性、ApplyToRuntime）移除即可；
;    旧 ini 残留键会被忽略，不影响加载
; 3. 重命名颜色键：保留一段 ini 旧键迁移（参见下方 Panel_FontColor 示例）
; 4. 缺省回退规则（兼容自定义主题与版本升级）：
;    任意路径取不到某 Key（未保存 / 预设未写 / Map 残缺）时，
;    一律使用默认主题（DefaultThemeKey）对应色，禁止用纯黑凑数（纯黑仅作开发兜底）
; 5. 自定义主题（AppTheme=Custom）：
;    以默认主题为底图，再叠加 ini 中已保存的逐项颜色；新增 Key 自动得默认色
; 6. 预设增删：只改 Presets；未知 Key 在 LoadFromIni 因 IsPresetKey 失败而回退到默认主题
; 7. 运行时浮层（菜单轮盘本体、界面浮窗面板、指令显示浮层）使用业务色（Wheel_* / Panel_* / CMD_*）；
;    节点编辑器与各设置窗走 ApplyXamlTheme（通用窗口色）
; =============================================================================

class AppThemeUtil {
    ; 颜色权威清单：UI 编辑项、ini 读写、完整 Map 均以此为准
    ; 分组顺序即主题选项页展示顺序；「通用窗口」置于菜单轮盘之上
    static ColorDefs := [
        {Key: "Win_TitleBg", Group: "通用窗口", Label: "标题背景"},
        {Key: "Win_TitleText", Group: "通用窗口", Label: "标题文本"},
        {Key: "Win_WindowBg", Group: "通用窗口", Label: "窗口背景"},
        {Key: "Win_GroupStroke", Group: "通用窗口", Label: "组描边"},
        {Key: "Win_GraphLine", Group: "通用窗口", Label: "图形线条"},
        {Key: "Win_LabelColor", Group: "通用窗口", Label: "标签颜色"},
        {Key: "Win_InputBg", Group: "通用窗口", Label: "输入框背景"},
        {Key: "Win_InputStroke", Group: "通用窗口", Label: "输入框描边"},
        {Key: "Win_InputText", Group: "通用窗口", Label: "输入框文本"},
        {Key: "Win_EditBg", Group: "通用窗口", Label: "编辑背景"},
        {Key: "Win_EditStroke", Group: "通用窗口", Label: "编辑描边"},
        {Key: "Win_EditText", Group: "通用窗口", Label: "编辑文本"},
        {Key: "Win_ActionBg", Group: "通用窗口", Label: "操作背景"},
        {Key: "Win_ActionStroke", Group: "通用窗口", Label: "操作描边"},
        {Key: "Win_ActionText", Group: "通用窗口", Label: "操作文本"},
        {Key: "Win_ProgressBar", Group: "通用窗口", Label: "进度条"},
        {Key: "Wheel_NormalText", Group: "菜单轮盘", Label: "常态文字"},
        {Key: "Wheel_NormalFill", Group: "菜单轮盘", Label: "常态填充"},
        {Key: "Wheel_NormalStroke", Group: "菜单轮盘", Label: "常态描边"},
        {Key: "Wheel_HoverText", Group: "菜单轮盘", Label: "悬停文字"},
        {Key: "Wheel_HoverFill", Group: "菜单轮盘", Label: "悬停填充"},
        {Key: "Wheel_HoverStroke", Group: "菜单轮盘", Label: "悬停描边"},
        {Key: "Wheel_SwipeLineColor", Group: "菜单轮盘", Label: "划线颜色"},
        {Key: "Panel_TitleBg", Group: "界面浮窗", Label: "标题背景"},
        {Key: "Panel_TitleText", Group: "界面浮窗", Label: "标题文本"},
        {Key: "Panel_BtnColor", Group: "界面浮窗", Label: "按钮背景"},
        {Key: "Panel_BtnText", Group: "界面浮窗", Label: "按钮文本"},
        {Key: "Panel_BgColor", Group: "界面浮窗", Label: "内容背景"},
        {Key: "CMD_FontColor", Group: "指令显示", Label: "字体颜色"},
        {Key: "CMD_BGColor", Group: "指令显示", Label: "背景颜色"},
        {Key: "CMD_RunBGColor", Group: "指令显示", Label: "运行背景"}
    ]

    ; 预设列表；DefaultThemeKey 对应项必须存在，且应含 ColorDefs 全部 Key
    ; 显示顺序：默认、霜灰、暗夜、暖阳、海洋、绯樱、抹茶、青瓷、暮紫
    static Presets := [
        ; Win_GraphLine：节点编辑器画布网格线（画布底固定深色，故各主题取低亮度色）
        {Key: "Default", Name: "默认",
            Win_TitleBg: "#FFEBEBEB", Win_TitleText: "#FF1A1A1A",
            Win_WindowBg: "#FFF0F0F0", Win_GroupStroke: "#FF999999", Win_GraphLine: "#FF333333", Win_LabelColor: "#FF1A1A1A",
            Win_InputBg: "#FFFFFFFF", Win_InputStroke: "#FFCCCCCC", Win_InputText: "#FF1A1A1A",
            Win_EditBg: "#FFFFFFFF", Win_EditStroke: "#FFCCCCCC", Win_EditText: "#FF1A1A1A",
            Win_ActionBg: "#FF0078D7", Win_ActionStroke: "#FF0078D7", Win_ActionText: "#FFFFFFFF",
            Win_ProgressBar: "#FF0078D7",
            Wheel_NormalText: "#CC1A365D", Wheel_NormalFill: "#FFF0F7FF", Wheel_NormalStroke: "#FF90CAF9",
            Wheel_HoverText: "#FF0078D7", Wheel_HoverFill: "#FFE3F2FD", Wheel_HoverStroke: "#FF0078D7",
            Wheel_SwipeLineColor: "#FF0078D7",
            Panel_TitleBg: "#FF0078D7", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FF0078D7", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#F2F5F9FC",
            CMD_FontColor: "#FF1A1A1A", CMD_BGColor: "#FFF5F5F5", CMD_RunBGColor: "#FF0078D7"},
        {Key: "FrostGray", Name: "霜灰",
            Win_TitleBg: "#FFE2E8F0", Win_TitleText: "#FF1E293B",
            Win_WindowBg: "#FFF8FAFC", Win_GroupStroke: "#FF94A3B8", Win_GraphLine: "#FF2E3540", Win_LabelColor: "#FF1E293B",
            Win_InputBg: "#FFFFFFFF", Win_InputStroke: "#FFCBD5E1", Win_InputText: "#FF1E293B",
            Win_EditBg: "#FFFFFFFF", Win_EditStroke: "#FF64748B", Win_EditText: "#FF334155",
            Win_ActionBg: "#FF475569", Win_ActionStroke: "#FF475569", Win_ActionText: "#FFFFFFFF",
            Win_ProgressBar: "#FF64748B",
            Wheel_NormalText: "#CC4B5563", Wheel_NormalFill: "#FFF8FAFC", Wheel_NormalStroke: "#FFCBD5E1",
            Wheel_HoverText: "#FF334155", Wheel_HoverFill: "#FFE2E8F0", Wheel_HoverStroke: "#FF64748B",
            Wheel_SwipeLineColor: "#FF64748B",
            Panel_TitleBg: "#FF475569", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FF334155", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#F2F1F5F9",
            CMD_FontColor: "#FF1E293B", CMD_BGColor: "#FFF8FAFC", CMD_RunBGColor: "#FF64748B"},
        {Key: "DarkNight", Name: "暗夜",
            Win_TitleBg: "#FF111111", Win_TitleText: "#FFE8E8E8",
            Win_WindowBg: "#FF1E1E1E", Win_GroupStroke: "#FF666666", Win_GraphLine: "#FF2A2A2A", Win_LabelColor: "#FFE0E0E0",
            Win_InputBg: "#FF2D2D2D", Win_InputStroke: "#FF6E6E6E", Win_InputText: "#FFE8E8E8",
            Win_EditBg: "#FF2D2D2D", Win_EditStroke: "#FF9E9E9E", Win_EditText: "#FFF0F0F0",
            Win_ActionBg: "#FF4A4A4A", Win_ActionStroke: "#FF6A6A6A", Win_ActionText: "#FFFFFFFF",
            Win_ProgressBar: "#FFB0B0B0",
            Wheel_NormalText: "#CCAAAAAA", Wheel_NormalFill: "#FF2D2D2D", Wheel_NormalStroke: "#FF555555",
            Wheel_HoverText: "#FFFFFFFF", Wheel_HoverFill: "#FF3D3D3D", Wheel_HoverStroke: "#FFB0B0B0",
            Wheel_SwipeLineColor: "#FFD0D0D0",
            Panel_TitleBg: "#FF111111", Panel_TitleText: "#FFE0E0E0",
            Panel_BtnColor: "#FF3A3A3A", Panel_BtnText: "#FFE0E0E0", Panel_BgColor: "#E01A1A1A",
            CMD_FontColor: "#FFE0E0E0", CMD_BGColor: "#FF1E1E1E", CMD_RunBGColor: "#FF5A5A5A"},
        {Key: "WarmSun", Name: "暖阳",
            Win_TitleBg: "#FFFFE4B5", Win_TitleText: "#FF5C3317",
            Win_WindowBg: "#FFFFF8DC", Win_GroupStroke: "#FFE8B86D", Win_GraphLine: "#FF3A3228", Win_LabelColor: "#FF5C3317",
            Win_InputBg: "#FFFFFFFF", Win_InputStroke: "#FFE8B86D", Win_InputText: "#FF5C3317",
            Win_EditBg: "#FFFFFFFF", Win_EditStroke: "#FFFF8C00", Win_EditText: "#FF8B4513",
            Win_ActionBg: "#FFFF8C00", Win_ActionStroke: "#FFE67E00", Win_ActionText: "#FFFFFFFF",
            Win_ProgressBar: "#FFFF8C00",
            Wheel_NormalText: "#CC8B4513", Wheel_NormalFill: "#FFFFF8DC", Wheel_NormalStroke: "#FFE8B86D",
            Wheel_HoverText: "#FFFF6347", Wheel_HoverFill: "#FFFFE4B5", Wheel_HoverStroke: "#FFFF6347",
            Wheel_SwipeLineColor: "#FFFF6347",
            Panel_TitleBg: "#FF8B4513", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FFFF8C00", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#C0FFE4B5",
            CMD_FontColor: "#FF5C3317", CMD_BGColor: "#FFFFF8DC", CMD_RunBGColor: "#FFFF8C00"},
        {Key: "Ocean", Name: "海洋",
            Win_TitleBg: "#FFD6EAF8", Win_TitleText: "#FF1A365D",
            Win_WindowBg: "#FFF0F8FF", Win_GroupStroke: "#FF7EB3E8", Win_GraphLine: "#FF283848", Win_LabelColor: "#FF1A365D",
            Win_InputBg: "#FFFFFFFF", Win_InputStroke: "#FF90CAF9", Win_InputText: "#FF1A365D",
            Win_EditBg: "#FFFFFFFF", Win_EditStroke: "#FF1E90FF", Win_EditText: "#FF1E90FF",
            Win_ActionBg: "#FF1E90FF", Win_ActionStroke: "#FF1E90FF", Win_ActionText: "#FFFFFFFF",
            Win_ProgressBar: "#FF1E90FF",
            Wheel_NormalText: "#CC2C5282", Wheel_NormalFill: "#FFF0F8FF", Wheel_NormalStroke: "#FF4682B4",
            Wheel_HoverText: "#FF1E90FF", Wheel_HoverFill: "#FFE0F0FF", Wheel_HoverStroke: "#FF1E90FF",
            Wheel_SwipeLineColor: "#FF1E90FF",
            Panel_TitleBg: "#FF2C5282", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FF1E90FF", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#C0E0F0FF",
            CMD_FontColor: "#FF1A365D", CMD_BGColor: "#FFF0F8FF", CMD_RunBGColor: "#FF1E90FF"},
        {Key: "PinkSakura", Name: "绯樱",
            Win_TitleBg: "#FFFFE4EC", Win_TitleText: "#FF9F1239",
            Win_WindowBg: "#FFFFF0F5", Win_GroupStroke: "#FFF9A8C4", Win_GraphLine: "#FF3A2830", Win_LabelColor: "#FF9F1239",
            Win_InputBg: "#FFFFFFFF", Win_InputStroke: "#FFFFB6C1", Win_InputText: "#FF9F1239",
            Win_EditBg: "#FFFFFFFF", Win_EditStroke: "#FFDB2777", Win_EditText: "#FFDB2777",
            Win_ActionBg: "#FFDB2777", Win_ActionStroke: "#FFDB2777", Win_ActionText: "#FFFFFFFF",
            Win_ProgressBar: "#FFF472B6",
            Wheel_NormalText: "#CC9F1239", Wheel_NormalFill: "#FFFFF0F5", Wheel_NormalStroke: "#FFFFB6C1",
            Wheel_HoverText: "#FFDB2777", Wheel_HoverFill: "#FFFFE4EC", Wheel_HoverStroke: "#FFDB2777",
            Wheel_SwipeLineColor: "#FFF472B6",
            Panel_TitleBg: "#FFDB2777", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FFE11D48", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#C0FFF0F5",
            CMD_FontColor: "#FF9F1239", CMD_BGColor: "#FFFFF0F5", CMD_RunBGColor: "#FFF472B6"},
        {Key: "Matcha", Name: "抹茶",
            Win_TitleBg: "#FFECF4D3", Win_TitleText: "#FF365314",
            Win_WindowBg: "#FFF7FBEA", Win_GroupStroke: "#FF8FA076", Win_GraphLine: "#FF2E3828", Win_LabelColor: "#FF365314",
            Win_InputBg: "#FFFFFFFF", Win_InputStroke: "#FFA3B18A", Win_InputText: "#FF365314",
            Win_EditBg: "#FFFFFFFF", Win_EditStroke: "#FF65A30D", Win_EditText: "#FF4D7C0F",
            Win_ActionBg: "#FF65A30D", Win_ActionStroke: "#FF65A30D", Win_ActionText: "#FFFFFFFF",
            Win_ProgressBar: "#FF84CC16",
            Wheel_NormalText: "#CC3F6218", Wheel_NormalFill: "#FFF7FBEA", Wheel_NormalStroke: "#FFA3B18A",
            Wheel_HoverText: "#FF4D7C0F", Wheel_HoverFill: "#FFECF4D3", Wheel_HoverStroke: "#FF65A30D",
            Wheel_SwipeLineColor: "#FF84CC16",
            Panel_TitleBg: "#FF4D7C0F", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FF65A30D", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#C0F0F7E0",
            CMD_FontColor: "#FF365314", CMD_BGColor: "#FFF7FBEA", CMD_RunBGColor: "#FF84CC16"},
        {Key: "Celadon", Name: "青瓷",
            Win_TitleBg: "#FFCCFBF1", Win_TitleText: "#FF134E4A",
            Win_WindowBg: "#FFF0FDFA", Win_GroupStroke: "#FF5EEAD4", Win_GraphLine: "#FF283836", Win_LabelColor: "#FF134E4A",
            Win_InputBg: "#FFFFFFFF", Win_InputStroke: "#FF99F6E4", Win_InputText: "#FF134E4A",
            Win_EditBg: "#FFFFFFFF", Win_EditStroke: "#FF14B8A6", Win_EditText: "#FF0F766E",
            Win_ActionBg: "#FF0D9488", Win_ActionStroke: "#FF0D9488", Win_ActionText: "#FFFFFFFF",
            Win_ProgressBar: "#FF14B8A6",
            Wheel_NormalText: "#CC115E59", Wheel_NormalFill: "#FFF0FDFA", Wheel_NormalStroke: "#FF99F6E4",
            Wheel_HoverText: "#FF0F766E", Wheel_HoverFill: "#FFCCFBF1", Wheel_HoverStroke: "#FF14B8A6",
            Wheel_SwipeLineColor: "#FF2DD4BF",
            Panel_TitleBg: "#FF0F766E", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FF0D9488", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#C0E6FFFA",
            CMD_FontColor: "#FF134E4A", CMD_BGColor: "#FFF0FDFA", CMD_RunBGColor: "#FF14B8A6"},
        {Key: "DuskPurple", Name: "暮紫",
            Win_TitleBg: "#FFF3E8FF", Win_TitleText: "#FF4C1D95",
            Win_WindowBg: "#FFFAF5FF", Win_GroupStroke: "#FFC4B5FD", Win_GraphLine: "#FF322840", Win_LabelColor: "#FF4C1D95",
            Win_InputBg: "#FFFFFFFF", Win_InputStroke: "#FFDDD6FE", Win_InputText: "#FF4C1D95",
            Win_EditBg: "#FFFFFFFF", Win_EditStroke: "#FF8B5CF6", Win_EditText: "#FF7C3AED",
            Win_ActionBg: "#FF7C3AED", Win_ActionStroke: "#FF7C3AED", Win_ActionText: "#FFFFFFFF",
            Win_ProgressBar: "#FFA78BFA",
            Wheel_NormalText: "#CC5B21B6", Wheel_NormalFill: "#FFFAF5FF", Wheel_NormalStroke: "#FFDDD6FE",
            Wheel_HoverText: "#FF7C3AED", Wheel_HoverFill: "#FFF3E8FF", Wheel_HoverStroke: "#FF8B5CF6",
            Wheel_SwipeLineColor: "#FFA78BFA",
            Panel_TitleBg: "#FF6D28D9", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FF7C3AED", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#C0F5F3FF",
            CMD_FontColor: "#FF4C1D95", CMD_BGColor: "#FFFAF5FF", CMD_RunBGColor: "#FF8B5CF6"}
    ]

    ; 程序默认主题（缺键 / 废弃预设 / Custom 底图均回退到此）
    static DefaultThemeKey := "Default"

    ; ---------- 预设查找 ----------

    static GetDefaultPreset() {
        for item in AppThemeUtil.Presets {
            if (item.Key == AppThemeUtil.DefaultThemeKey)
                return item
        }
        ; 开发期保底：Presets 首项应与 DefaultThemeKey 保持一致
        return AppThemeUtil.Presets[1]
    }

    static IsPresetKey(key) {
        if (key == "Custom")
            return true
        for item in AppThemeUtil.Presets {
            if (item.Key == key)
                return true
        }
        return false
    }

    static FindPreset(key) {
        for item in AppThemeUtil.Presets {
            if (item.Key == key)
                return item
        }
        return AppThemeUtil.GetDefaultPreset()
    }

    static FindPresetByName(name) {
        for item in AppThemeUtil.Presets {
            if (item.Name == name || GetLang(item.Name) == name)
                return item
        }
        return ""
    }

    ; ColorDefs 中 Group 去重顺序（供主题设置 UI 自动分组）
    static GetGroupNames() {
        names := []
        seen := Map()
        for def in AppThemeUtil.ColorDefs {
            if (!seen.Has(def.Group)) {
                seen[def.Group] := true
                names.Push(def.Group)
            }
        }
        return names
    }

    ; ---------- 颜色解析与完整 Map（兼容核心）----------

    ; 默认主题上某 Key 的标准色；默认主题也未定义时才回退纯黑（应避免出现）
    static GetDefaultColor(key) {
        preset := AppThemeUtil.GetDefaultPreset()
        if (preset.HasProp(key))
            return AppThemeUtil.NormalizeArgb(preset.%key%)
        return "#FF000000"
    }

    ; 从 colors Map 取色；缺键 / 空值 → 默认主题
    static ResolveColor(colors, key) {
        if (IsObject(colors) && colors.Has(key)) {
            val := colors[key]
            if (val != "")
                return AppThemeUtil.NormalizeArgb(val)
        }
        return AppThemeUtil.GetDefaultColor(key)
    }

    ; 以默认主题为底，再叠加 overlay（Map 或 Preset 对象），保证含 ColorDefs 全部 Key
    ; 用于：选预设、加载自定义残缺配置、克隆后补齐新增项
    static BuildCompleteColorMap(overlay := "") {
        colors := Map()
        base := AppThemeUtil.GetDefaultPreset()
        for def in AppThemeUtil.ColorDefs {
            key := def.Key
            val := ""
            if (IsObject(overlay)) {
                if (overlay is Map) {
                    if (overlay.Has(key) && overlay[key] != "")
                        val := overlay[key]
                } else if (overlay.HasProp(key)) {
                    propVal := overlay.%key%
                    if (propVal != "")
                        val := propVal
                }
            }
            if (val == "")
                val := base.HasProp(key) ? base.%key% : "#FF000000"
            colors[key] := AppThemeUtil.NormalizeArgb(val)
        }
        return colors
    }

    ; 由预设生成完整颜色 Map（预设缺属性时补默认主题色）
    static NewColorMapFromPreset(preset) {
        return AppThemeUtil.BuildCompleteColorMap(preset)
    }

    ; 克隆并补齐：旧自定义 / 内存残缺 Map 升级后自动带上新 Key（默认主题色）
    static CloneColorMap(src) {
        return AppThemeUtil.BuildCompleteColorMap(IsObject(src) ? src : "")
    }

    ; #AARRGGBB / AARRGGBB / RRGGBB -> 6 位 RGB（供 AHK Gui.BackColor）
    static ArgbToRgb6(color) {
        s := StrReplace(color, "#")
        if (StrLen(s) >= 8)
            return SubStr(s, 3, 6)
        if (StrLen(s) == 6)
            return s
        return "000000"
    }

    static NormalizeArgb(color) {
        s := StrReplace(String(color), "#")
        if (StrLen(s) == 6)
            return "#FF" s
        if (StrLen(s) == 8)
            return "#" s
        return "#FF000000"
    }

    static MapGet(colors, key, defaultVal) {
        if (IsObject(colors) && colors.Has(key) && colors[key] != "")
            return colors[key]
        return defaultVal
    }

    ; ---------- 运行时同步 ----------

    ; 将 ThemeColors 同步到各运行时字段（缺键走 ResolveColor → 默认主题）
    static ApplyToRuntime(colors) {
        if (!IsObject(colors))
            colors := Map()
        ; BuildComplete 只保留 ColorDefs：旧键须在补齐前取出
        legacyBtnText := AppThemeUtil.MapGet(colors, "Panel_FontColor", "")
        colors := AppThemeUtil.BuildCompleteColorMap(colors)

        MainSoftData.UIPanelTitleBg := AppThemeUtil.ResolveColor(colors, "Panel_TitleBg")
        MainSoftData.UIPanelTitleText := AppThemeUtil.ResolveColor(colors, "Panel_TitleText")
        MainSoftData.UIPanelBtnColor := AppThemeUtil.ResolveColor(colors, "Panel_BtnColor")

        ; 按钮文本：优先 Panel_BtnText；兼容旧键 Panel_FontColor
        btnText := AppThemeUtil.MapGet(colors, "Panel_BtnText", "")
        if (btnText == "" && legacyBtnText != "")
            btnText := legacyBtnText
        if (btnText == "")
            btnText := AppThemeUtil.GetDefaultColor("Panel_BtnText")
        MainSoftData.UIPanelBtnText := AppThemeUtil.NormalizeArgb(btnText)
        MainSoftData.UIPanelFontColor := MainSoftData.UIPanelBtnText  ; 兼容旧字段名

        MainSoftData.UIPanelBgColor := AppThemeUtil.ResolveColor(colors, "Panel_BgColor")
        MainSoftData.CMDFontColor := AppThemeUtil.ArgbToRgb6(AppThemeUtil.ResolveColor(colors, "CMD_FontColor"))
        MainSoftData.CMDBGColor := AppThemeUtil.ArgbToRgb6(AppThemeUtil.ResolveColor(colors, "CMD_BGColor"))
        MainSoftData.CMDRunBGColor := AppThemeUtil.ArgbToRgb6(AppThemeUtil.ResolveColor(colors, "CMD_RunBGColor"))
    }

    static ApplyPreset(key) {
        preset := AppThemeUtil.FindPreset(key)
        MainSoftData.AppTheme := preset.Key
        MainSoftData.ThemeColors := AppThemeUtil.NewColorMapFromPreset(preset)
        AppThemeUtil.ApplyToRuntime(MainSoftData.ThemeColors)
    }

    ; ---------- ini 读写 ----------

    static LoadFromIni() {
        section := "ThemeColors"
        themeKey := IniRead(IniFile, section, "AppTheme", AppThemeUtil.DefaultThemeKey)
        ; 空值、未知 Key → 默认主题
        if (themeKey == "" || !AppThemeUtil.IsPresetKey(themeKey))
            themeKey := AppThemeUtil.DefaultThemeKey
        MainSoftData.AppTheme := themeKey

        ; Custom：底图=默认主题；具名预设：底图=该预设（缺属性仍补默认主题）
        baseKey := (themeKey == "Custom") ? AppThemeUtil.DefaultThemeKey : themeKey
        colors := AppThemeUtil.NewColorMapFromPreset(AppThemeUtil.FindPreset(baseKey))

        ; 逐项覆盖：ini 有值才覆盖；新增 ColorDefs Key 在 ini 中不存在时保留底图色
        for def in AppThemeUtil.ColorDefs {
            saved := IniRead(IniFile, section, def.Key, "")
            if (saved != "")
                colors[def.Key] := AppThemeUtil.NormalizeArgb(saved)
        }

        ; 旧键迁移示例：Panel_FontColor → Panel_BtnText（仅当新键未写入时）
        legacyBtnText := IniRead(IniFile, section, "Panel_FontColor", "")
        if (legacyBtnText != "" && IniRead(IniFile, section, "Panel_BtnText", "") == "")
            colors["Panel_BtnText"] := AppThemeUtil.NormalizeArgb(legacyBtnText)

        MainSoftData.ThemeColors := colors
        AppThemeUtil.ApplyToRuntime(colors)
    }

    static SaveToIni() {
        section := "ThemeColors"
        ; 保存前补齐，避免漏写新增 Key
        MainSoftData.ThemeColors := AppThemeUtil.CloneColorMap(MainSoftData.ThemeColors)
        IniWrite(MainSoftData.AppTheme, IniFile, section, "AppTheme")
        for def in AppThemeUtil.ColorDefs {
            val := AppThemeUtil.ResolveColor(MainSoftData.ThemeColors, def.Key)
            IniWrite(val, IniFile, section, def.Key)
        }
        ; 同步旧版扁平键（主题权威来源仍是 [ThemeColors]）
        IniWrite(MainSoftData.UIPanelTitleBg, IniFile, IniSection, "UIPanelTitleBg")
        IniWrite(MainSoftData.UIPanelTitleText, IniFile, IniSection, "UIPanelTitleText")
        IniWrite(MainSoftData.UIPanelBtnColor, IniFile, IniSection, "UIPanelBtnColor")
        IniWrite(MainSoftData.UIPanelBtnText, IniFile, IniSection, "UIPanelBtnText")
        IniWrite(MainSoftData.UIPanelBgColor, IniFile, IniSection, "UIPanelBgColor")
        IniWrite(MainSoftData.CMDBGColor, IniFile, IniSection, "CMDBGColor")
        IniWrite(MainSoftData.CMDRunBGColor, IniFile, IniSection, "CMDRunBGColor")
        IniWrite(MainSoftData.CMDFontColor, IniFile, IniSection, "CMDFontColor")
        IniWrite(MainSoftData.AppTheme, IniFile, IniSection, "AppTheme")
    }

    ; 轮盘取色：ThemeColors → 默认主题；defaultVal 仅作额外兜底（调用方可省略）
    static GetWheelColor(name, defaultVal := "") {
        key := "Wheel_" name
        if (IsObject(MainSoftData.ThemeColors) && MainSoftData.ThemeColors.Has(key)
            && MainSoftData.ThemeColors[key] != "")
            return MainSoftData.ThemeColors[key]
        warm := AppThemeUtil.GetDefaultColor(key)
        if (warm != "#FF000000")
            return warm
        return (defaultVal != "") ? defaultVal : warm
    }

    ; 将「通用窗口」色写入已打开的 XAML 窗口 Resource（及标题栏 DragArea）
    ; colors 可传编辑中的草稿 Map；省略则用 MainSoftData.ThemeColors
    static ApplyWinThemeToXaml(ui, colors := "") {
        if (!IsObject(ui))
            return
        if (!IsObject(colors))
            colors := IsObject(MainSoftData.ThemeColors) ? MainSoftData.ThemeColors : Map()
        colors := AppThemeUtil.BuildCompleteColorMap(colors)

        titleBg := AppThemeUtil.ResolveColor(colors, "Win_TitleBg")
        titleText := AppThemeUtil.ResolveColor(colors, "Win_TitleText")
        windowBg := AppThemeUtil.ResolveColor(colors, "Win_WindowBg")
        groupStroke := AppThemeUtil.ResolveColor(colors, "Win_GroupStroke")
        graphLine := AppThemeUtil.ResolveColor(colors, "Win_GraphLine")
        labelColor := AppThemeUtil.ResolveColor(colors, "Win_LabelColor")
        inputBg := AppThemeUtil.ResolveColor(colors, "Win_InputBg")
        inputStroke := AppThemeUtil.ResolveColor(colors, "Win_InputStroke")
        inputText := AppThemeUtil.ResolveColor(colors, "Win_InputText")
        editBg := AppThemeUtil.ResolveColor(colors, "Win_EditBg")
        editStroke := AppThemeUtil.ResolveColor(colors, "Win_EditStroke")
        editText := AppThemeUtil.ResolveColor(colors, "Win_EditText")
        actionBg := AppThemeUtil.ResolveColor(colors, "Win_ActionBg")
        actionStroke := AppThemeUtil.ResolveColor(colors, "Win_ActionStroke")
        actionText := AppThemeUtil.ResolveColor(colors, "Win_ActionText")
        progress := AppThemeUtil.ResolveColor(colors, "Win_ProgressBar")

        try ui.Update("Resource", "TitleBarColor", titleBg)
        try ui.Update("Resource", "TitleBarForeground", titleText)
        try ui.Update("Resource", "BgColor", windowBg)
        try ui.Update("Resource", "TextMain", labelColor)
        try ui.Update("Resource", "ControlBg", windowBg)
        try ui.Update("Resource", "ControlBorder", groupStroke)
        try ui.Update("Resource", "GroupStroke", groupStroke)
        try ui.Update("Resource", "GraphLine", graphLine)
        try ui.Update("Resource", "InputBg", inputBg)
        try ui.Update("Resource", "InputStroke", inputStroke)
        try ui.Update("Resource", "InputText", inputText)
        try ui.Update("Resource", "EditBg", editBg)
        try ui.Update("Resource", "EditStroke", editStroke)
        try ui.Update("Resource", "EditText", editText)
        try ui.Update("Resource", "ActionBg", actionBg)
        try ui.Update("Resource", "ActionStroke", actionStroke)
        try ui.Update("Resource", "ActionText", actionText)
        try ui.Update("Resource", "Accent", progress)
        try ui.Update("Resource", "ProgressBar", progress)
        ; 下拉弹出层与输入框同色，避免浅色底 + 深色主题文字导致看不清
        try ui.Update("Resource", "DropdownBg", inputBg)
        try ui.Update("DragArea", "Background", titleBg)
        try ui.Update("Window", "Background", windowBg)
    }

    ; 刷新已打开的通用窗口类设置界面（主题保存后同步）
    static RefreshOpenSettingWindows() {
        classes := [HotkeySettingGui, ToolRecordSettingGui, MenuWheelGlobalSettingGui,
            UIMacroPanelSettingGui, CMDTipSettingGui, ThemeSettingGui]
        for cls in classes {
            try {
                if (!IsObject(cls) || !cls.HasOwnProp("instances"))
                    continue
                for , inst in cls.instances {
                    if (!inst.closed && IsObject(inst.ui))
                        AppThemeUtil.ApplyWinThemeToXaml(inst.ui)
                }
            }
        }
    }
}

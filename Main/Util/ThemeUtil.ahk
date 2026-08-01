#Requires AutoHotkey v2.0

; =============================================================================
; AppThemeUtil — 统一主题颜色（轮盘 / 界面浮窗 / 指令显示等）
;
; 存储：MainSettings.ini [ThemeColors]
; 运行时：同步到 MainSoftData.ThemeColors，以及各消费字段（UIPanel* / CMD*）
;
; ---------- 扩展约定（增删改颜色 / 预设时请遵守）----------
; 1. 新增颜色项：
;    - 在 ColorDefs 增加 {Key, Group, Label}
;    - 至少在暖阳（DefaultThemeKey）Preset 上写上同名属性；其它预设建议一并补齐
;    - 若该色需驱动运行时字段，在 ApplyToRuntime 增加映射
;    - 主题设置 UI 按 ColorDefs 的 Group 自动排布，一般不必改 ThemeSettingGui
; 2. 删除颜色项：从 ColorDefs（及各 Preset 属性、ApplyToRuntime）移除即可；
;    旧 ini 残留键会被忽略，不影响加载
; 3. 重命名颜色键：保留一段 ini 旧键迁移（参见下方 Panel_FontColor 示例）
; 4. 缺省回退规则（兼容自定义主题与版本升级）：
;    任意路径取不到某 Key（未保存 / 预设未写 / Map 残缺）时，
;    一律使用暖阳（DefaultThemeKey）对应色，禁止用纯黑凑数（纯黑仅作开发兜底）
; 5. 自定义主题（AppTheme=Custom）：
;    以暖阳为底图，再叠加 ini 中已保存的逐项颜色；新增 Key 自动得暖阳色
; 6. 预设增删：只改 Presets；已废弃预设 Key（如旧 Default/Neon）在 LoadFromIni
;    因 IsPresetKey 失败而回退到暖阳
; =============================================================================

class AppThemeUtil {
    ; 颜色权威清单：UI 编辑项、ini 读写、完整 Map 均以此为准
    static ColorDefs := [
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
    static Presets := [
        {Key: "WarmSun", Name: "暖阳",
            Wheel_NormalText: "#CC8B4513", Wheel_NormalFill: "#FFFFF8DC", Wheel_NormalStroke: "#FFDAA520",
            Wheel_HoverText: "#FFFF6347", Wheel_HoverFill: "#FFFFE4B5", Wheel_HoverStroke: "#FFFF6347",
            Wheel_SwipeLineColor: "#FFFF6347",
            Panel_TitleBg: "#FF8B4513", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FFDAA520", Panel_BtnText: "#FF5C3317", Panel_BgColor: "#C0FFE4B5",
            CMD_FontColor: "#FF5C3317", CMD_BGColor: "#FFFFF8DC", CMD_RunBGColor: "#FFFF8C00"},
        {Key: "DarkNight", Name: "暗夜",
            Wheel_NormalText: "#CCAAAAAA", Wheel_NormalFill: "#FF2D2D2D", Wheel_NormalStroke: "#FF555555",
            Wheel_HoverText: "#FF00BFFF", Wheel_HoverFill: "#FF3D3D3D", Wheel_HoverStroke: "#FF00BFFF",
            Wheel_SwipeLineColor: "#FF00BFFF",
            Panel_TitleBg: "#FF111111", Panel_TitleText: "#FFE0E0E0",
            Panel_BtnColor: "#FF3A3A3A", Panel_BtnText: "#FFE0E0E0", Panel_BgColor: "#E01A1A1A",
            CMD_FontColor: "#FFE0E0E0", CMD_BGColor: "#FF1E1E1E", CMD_RunBGColor: "#FF007AAF"},
        {Key: "Ocean", Name: "海洋",
            Wheel_NormalText: "#CC2C5282", Wheel_NormalFill: "#FFF0F8FF", Wheel_NormalStroke: "#FF4682B4",
            Wheel_HoverText: "#FF1E90FF", Wheel_HoverFill: "#FFE0F0FF", Wheel_HoverStroke: "#FF1E90FF",
            Wheel_SwipeLineColor: "#FF1E90FF",
            Panel_TitleBg: "#FF2C5282", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FF1E90FF", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#C0E0F0FF",
            CMD_FontColor: "#FF1A365D", CMD_BGColor: "#FFF0F8FF", CMD_RunBGColor: "#FF1E90FF"},
        {Key: "PinkSakura", Name: "绯樱",
            Wheel_NormalText: "#CC9F1239", Wheel_NormalFill: "#FFFFF0F5", Wheel_NormalStroke: "#FFFFB6C1",
            Wheel_HoverText: "#FFDB2777", Wheel_HoverFill: "#FFFFE4EC", Wheel_HoverStroke: "#FFDB2777",
            Wheel_SwipeLineColor: "#FFF472B6",
            Panel_TitleBg: "#FFDB2777", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FFE11D48", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#C0FFF0F5",
            CMD_FontColor: "#FF9F1239", CMD_BGColor: "#FFFFF0F5", CMD_RunBGColor: "#FFF472B6"},
        {Key: "Matcha", Name: "抹茶",
            Wheel_NormalText: "#CC3F6218", Wheel_NormalFill: "#FFF7FBEA", Wheel_NormalStroke: "#FFA3B18A",
            Wheel_HoverText: "#FF4D7C0F", Wheel_HoverFill: "#FFECF4D3", Wheel_HoverStroke: "#FF65A30D",
            Wheel_SwipeLineColor: "#FF84CC16",
            Panel_TitleBg: "#FF4D7C0F", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FF65A30D", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#C0F0F7E0",
            CMD_FontColor: "#FF365314", CMD_BGColor: "#FFF7FBEA", CMD_RunBGColor: "#FF84CC16"},
        {Key: "FrostGray", Name: "霜灰",
            Wheel_NormalText: "#CC4B5563", Wheel_NormalFill: "#FFF8FAFC", Wheel_NormalStroke: "#FFCBD5E1",
            Wheel_HoverText: "#FF334155", Wheel_HoverFill: "#FFE2E8F0", Wheel_HoverStroke: "#FF64748B",
            Wheel_SwipeLineColor: "#FF64748B",
            Panel_TitleBg: "#FF475569", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FF334155", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#F2F1F5F9",
            CMD_FontColor: "#FF1E293B", CMD_BGColor: "#FFF8FAFC", CMD_RunBGColor: "#FF64748B"},
        {Key: "Celadon", Name: "青瓷",
            Wheel_NormalText: "#CC115E59", Wheel_NormalFill: "#FFF0FDFA", Wheel_NormalStroke: "#FF99F6E4",
            Wheel_HoverText: "#FF0F766E", Wheel_HoverFill: "#FFCCFBF1", Wheel_HoverStroke: "#FF14B8A6",
            Wheel_SwipeLineColor: "#FF2DD4BF",
            Panel_TitleBg: "#FF0F766E", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FF0D9488", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#C0E6FFFA",
            CMD_FontColor: "#FF134E4A", CMD_BGColor: "#FFF0FDFA", CMD_RunBGColor: "#FF14B8A6"},
        {Key: "DuskPurple", Name: "暮紫",
            Wheel_NormalText: "#CC5B21B6", Wheel_NormalFill: "#FFFAF5FF", Wheel_NormalStroke: "#FFDDD6FE",
            Wheel_HoverText: "#FF7C3AED", Wheel_HoverFill: "#FFF3E8FF", Wheel_HoverStroke: "#FF8B5CF6",
            Wheel_SwipeLineColor: "#FFA78BFA",
            Panel_TitleBg: "#FF6D28D9", Panel_TitleText: "#FFFFFFFF",
            Panel_BtnColor: "#FF7C3AED", Panel_BtnText: "#FFFFFFFF", Panel_BgColor: "#C0F5F3FF",
            CMD_FontColor: "#FF4C1D95", CMD_BGColor: "#FFFAF5FF", CMD_RunBGColor: "#FF8B5CF6"}
    ]

    ; 程序默认主题（缺键 / 废弃预设 / Custom 底图均回退到此）
    static DefaultThemeKey := "WarmSun"

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

    ; 暖阳上某 Key 的标准色；暖阳也未定义时才回退纯黑（应避免出现）
    static GetDefaultColor(key) {
        preset := AppThemeUtil.GetDefaultPreset()
        if (preset.HasProp(key))
            return AppThemeUtil.NormalizeArgb(preset.%key%)
        return "#FF000000"
    }

    ; 从 colors Map 取色；缺键 / 空值 → 暖阳
    static ResolveColor(colors, key) {
        if (IsObject(colors) && colors.Has(key)) {
            val := colors[key]
            if (val != "")
                return AppThemeUtil.NormalizeArgb(val)
        }
        return AppThemeUtil.GetDefaultColor(key)
    }

    ; 以暖阳为底，再叠加 overlay（Map 或 Preset 对象），保证含 ColorDefs 全部 Key
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

    ; 由预设生成完整颜色 Map（预设缺属性时补暖阳）
    static NewColorMapFromPreset(preset) {
        return AppThemeUtil.BuildCompleteColorMap(preset)
    }

    ; 克隆并补齐：旧自定义 / 内存残缺 Map 升级后自动带上新 Key（暖阳色）
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

    ; 将 ThemeColors 同步到各运行时字段（缺键走 ResolveColor → 暖阳）
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
        ; 空值、已移除预设（如旧 Default/Neon）、未知 Key → 暖阳
        if (themeKey == "" || !AppThemeUtil.IsPresetKey(themeKey))
            themeKey := AppThemeUtil.DefaultThemeKey
        MainSoftData.AppTheme := themeKey

        ; Custom：底图=暖阳；具名预设：底图=该预设（缺属性仍补暖阳）
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

    ; 轮盘取色：ThemeColors → 暖阳；defaultVal 仅作额外兜底（调用方可省略）
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
}

#Requires AutoHotkey v2.0

class LineOverlay {
    static hwnd := 0
    static hdc := 0
    static memDC := 0
    static bmp := 0
    static oldBmp := 0
    static gui := 0

    static Init() {
        if this.hwnd
            return

        this.gui := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
        this.gui.BackColor := "000000"
        WinSetTransColor("000000", this.gui)

        this.gui.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight)
        this.hwnd := this.gui.Hwnd

        this.hdc := DllCall("GetDC", "ptr", this.hwnd, "ptr")
        this.memDC := DllCall("CreateCompatibleDC", "ptr", this.hdc, "ptr")

        this.bmp := DllCall(
            "CreateCompatibleBitmap"
            , "ptr", this.hdc
            , "int", A_ScreenWidth
            , "int", A_ScreenHeight
            , "ptr"
        )

        this.oldBmp := DllCall("SelectObject", "ptr", this.memDC, "ptr", this.bmp, "ptr")
    }

    ; === 每一幀開始時呼叫 ===
    static BeginFrame() {
        ; 用黑色清空（黑色 = 透明）
        DllCall(
            "PatBlt"
            , "ptr", this.memDC
            , "int", 0, "int", 0
            , "int", A_ScreenWidth
            , "int", A_ScreenHeight
            , "uint", 0x00000042 ; BLACKNESS（關鍵）
        )
    }

    ; === 畫線（只畫，不刷新）===
    static DrawLine(
        x1, y1, x2, y2,
        lineColor := 0x00FF00,
        lineWidth := 3,
        strokeColor := 0x3A88F5,
        strokeWidth := 1
    ) {
        ; 描邊
        if (strokeWidth > 0) {
            hPen := DllCall(
                "CreatePen"
                , "int", 0
                , "int", lineWidth + strokeWidth * 2
                , "uint", strokeColor
                , "ptr"
            )
            old := DllCall("SelectObject", "ptr", this.memDC, "ptr", hPen, "ptr")
            DllCall("MoveToEx", "ptr", this.memDC, "int", x1, "int", y1, "ptr", 0)
            DllCall("LineTo", "ptr", this.memDC, "int", x2, "int", y2)
            DllCall("SelectObject", "ptr", this.memDC, "ptr", old)
            DllCall("DeleteObject", "ptr", hPen)
        }

        ; 主線
        hPen := DllCall(
            "CreatePen"
            , "int", 0
            , "int", lineWidth
            , "uint", lineColor
            , "ptr"
        )
        old := DllCall("SelectObject", "ptr", this.memDC, "ptr", hPen, "ptr")
        DllCall("MoveToEx", "ptr", this.memDC, "int", x1, "int", y1, "ptr", 0)
        DllCall("LineTo", "ptr", this.memDC, "int", x2, "int", y2)
        DllCall("SelectObject", "ptr", this.memDC, "ptr", old)
        DllCall("DeleteObject", "ptr", hPen)
    }

    ; === 每一幀結束時呼叫 ===
    static EndFrame() {
        DllCall(
            "BitBlt"
            , "ptr", this.hdc
            , "int", 0, "int", 0
            , "int", A_ScreenWidth
            , "int", A_ScreenHeight
            , "ptr", this.memDC
            , "int", 0, "int", 0
            , "uint", 0x00CC0020 ; SRCCOPY
        )
    }

    static Destroy() {
        if this.memDC {
            DllCall("SelectObject", "ptr", this.memDC, "ptr", this.oldBmp)
            DllCall("DeleteObject", "ptr", this.bmp)
            DllCall("DeleteDC", "ptr", this.memDC)
            DllCall("ReleaseDC", "ptr", this.hwnd, "ptr", this.hdc)
        }
        this.gui.Destroy()
        this.hwnd := 0
    }
}
#Requires AutoHotkey v2.0

ExcelCellToWrite(wbPath, sheetIdentifier, row, col, value) {
    try {
        xlWorkbook := ComObjGet(wbPath)
        xlApp := xlWorkbook.Application
        if (!xlApp.Visible) {
            xlWorkbook.Close()
            xlApp.Quit()
            xlApp := ComObject("Excel.Application")
            xlWorkbook := xlApp.Workbooks.Open(wbPath, 0, false)  ; 非只读模式打开
        }
        if (IsInteger(sheetIdentifier))
            sheetIdentifier := Integer(sheetIdentifier)
        sheet := xlWorkbook.Sheets(sheetIdentifier)
        sheet.Cells(row, col).Value := value
        xlWorkbook.Save()
        return true
    }
    catch as e {
        MsgBox GetLang("写入失败：") e.Message
        return false
    }
    finally {
        xlApp := xlWorkbook.Application
        if (!xlApp.Visible) {
            xlWorkbook.Close()
            xlApp.Quit()
        }
        xlWorkbook := ""
        xlApp := ""
    }
}

ExcelRowToWrite(wbPath, sheetIdentifier, col, value) {
    try {
        xlWorkbook := ComObjGet(wbPath)
        xlApp := xlWorkbook.Application
        if (!xlApp.Visible) {
            xlWorkbook.Close()
            xlApp.Quit()
            xlApp := ComObject("Excel.Application")
            xlWorkbook := xlApp.Workbooks.Open(wbPath, 0, false)  ; 非只读模式打开
        }
        if (IsInteger(sheetIdentifier))
            sheetIdentifier := Integer(sheetIdentifier)
        sheet := xlWorkbook.Sheets(sheetIdentifier)
        row := 1
        loop {
            if (sheet.Cells(A_Index, col).Text == "") {
                row := A_Index
                break
            }
        }
        sheet.Cells(row, col).Value := value
        xlWorkbook.Save()
        return true
    }
    catch as e {
        MsgBox GetLang("写入失败：") e.Message
        return false
    }
    finally {
        xlApp := xlWorkbook.Application
        if (!xlApp.Visible) {
            xlWorkbook.Close()
            xlApp.Quit()
        }
        xlWorkbook := ""
        xlApp := ""
    }
}

ExcelColToWrite(wbPath, sheetIdentifier, row, value) {
    try {
        xlWorkbook := ComObjGet(wbPath)
        xlApp := xlWorkbook.Application
        if (!xlApp.Visible) {
            xlWorkbook.Close()
            xlApp.Quit()
            xlApp := ComObject("Excel.Application")
            xlWorkbook := xlApp.Workbooks.Open(wbPath, 0, false)  ; 非只读模式打开
        }
        if (IsInteger(sheetIdentifier))
            sheetIdentifier := Integer(sheetIdentifier)
        sheet := xlWorkbook.Sheets(sheetIdentifier)
        col := 1
        loop {
            if (sheet.Cells(row, A_Index).Text == "") {
                col := A_Index
                break
            }
        }
        sheet.Cells(row, col).Value := value
        xlWorkbook.Save()
        return true
    }
    catch as e {
        MsgBox GetLang("写入失败：") e.Message
        return false
    }
    finally {
        xlApp := xlWorkbook.Application
        if (!xlApp.Visible) {
            xlWorkbook.Close()
            xlApp.Quit()
        }
        xlWorkbook := ""
        xlApp := ""
    }
}

ExcelCellToRead(wbPath, sheetIdentifier, row, col, &ResValue) {
    try {
        xlWorkbook := ComObjGet(wbPath)
        xlApp := xlWorkbook.Application
        xlApp.CalculateFullRebuild()
        if (IsInteger(sheetIdentifier))
            sheetIdentifier := Integer(sheetIdentifier)
        sheet := xlWorkbook.Sheets(sheetIdentifier)

         ; 获取单元格
        cell := sheet.Cells(row, col)
        
        ; 等待计算完成（如果包含公式）
        if cell.HasFormula {
            ; 检查计算状态
            while (xlApp.CalculationState != -4105) {  ; xlDone = -4105
                Sleep 100
            }
        }

        aa := cell.Text
        bb := cell.Formula
        cc := cell.FormulaR1C1
        dd := cell.HasFormula
        ee := cell.Row
        ff := cell.Column
        gg := cell.Value
        hh := cell.Value2
        ResValue := cell.Text
        return true
    }
    catch as e {
        MsgBox GetLang("读取失败：") e.Message
        return false
    }
    finally {
        xlApp := xlWorkbook.Application
        xlWorkbook := ""
        xlApp := ""
    }
}

; 读取Excel指定单元格内容（修复Value获取失败问题）
; 参数说明：
;   wbPath: Excel文件路径
;   sheetIdentifier: 工作表标识（数字索引或工作表名称）
;   row: 行号（整数）
;   col: 列号（整数）
; 返回值：成功返回单元格内容（空单元格返回空字符串），失败返回空字符串
; ExcelCellToRead(wbPath, sheetIdentifier, row, col) {
;     local xlWorkbook := "", xlApp := "", sheet := "", cell := "", cellValue := ""

;     try {
;         ; 尝试获取已打开的Excel工作簿
;         xlWorkbook := ComObjGet(wbPath)
;         xlApp := xlWorkbook.Application

;         ; 如果Excel不可见，关闭后台实例后重新打开
;         if (!xlApp.Visible) {
;             xlWorkbook.Close()
;             xlApp.Quit()
;             xlApp := ComObject("Excel.Application")
;             xlWorkbook := xlApp.Workbooks.Open(wbPath, 0, false)  ; 非只读模式
;         }

;         ; 确保Excel实例在后台运行（避免弹窗干扰）
;         xlApp.Visible := false
;         xlApp.DisplayAlerts := false

;         ; 处理工作表标识（数字转整数）
;         if (IsInteger(sheetIdentifier))
;             sheetIdentifier := Integer(sheetIdentifier)

;         ; 获取工作表
;         sheet := xlWorkbook.Sheets(sheetIdentifier)
;         ; 先获取单元格对象，再取值（避免直接链式调用出错）
;         cell := sheet.Cells(row, col)
;         aa := cell.Text
;         bb := cell.Formula
;         cc := cell.FormulaR1C1
;         dd := cell.HasFormula
;         ee := cell.Row
;         ff := cell.Column
;         gg := cell.Value
;         ; 优先使用Value2（兼容性更强），兼容空单元格/公式/特殊格式
;         if (!IsObject(cell)) {
;             cellValue := ""
;         } else {
;             ; 尝试获取Value2，失败则降级到Text
;             try {
;                 cellValue := cell.Value2
;             } catch {
;                 cellValue := cell.Text
;             }
;             ; 处理COM对象返回的空值（转换为标准空字符串）
;             if (cellValue = "") || IsSet(cellValue) && cellValue = ""
;                 cellValue := ""
;         }

;         return cellValue
;     }
;     catch as e {
;         MsgBox GetLang("读取失败：") e.Message "`n错误行：" e.Line
;         return ""
;     }
;     finally {
;         ; 确保释放所有资源
;         if (xlWorkbook != "") {
;             xlApp := xlWorkbook.Application
;             xlApp.DisplayAlerts := true  ; 恢复默认提示
;             if (!xlApp.Visible) {
;                 xlWorkbook.Close(false)  ; 读取操作无需保存，false避免弹窗
;                 xlApp.Quit()
;             }
;         }
;         ; 清空所有COM对象引用，防止内存泄漏
;         cell := ""
;         sheet := ""
;         xlWorkbook := ""
;         xlApp := ""
;     }
; }

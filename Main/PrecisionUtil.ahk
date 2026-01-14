#Requires AutoHotkey v2.0

PrecisionAdd(AValue, BValue, N := 6) {
    ; 如果两个都是整数，直接返回结果
    if (IsInteger(AValue) && IsInteger(BValue))
        return AValue + BValue

    res := Round(AValue + BValue, N)
    res := TrimZeros(res)    ; 清理末尾多余的0
    return res
}

; 辅助函数：去除末尾多余的0
TrimZeros(num_str) {
    if (!InStr(num_str, "."))
        return num_str
    
    ; 去除末尾的0
    while (SubStr(num_str, -1) = "0")
        num_str := SubStr(num_str, 1, -1)
    
    ; 如果小数部分全部是0，去除小数点
    if (SubStr(num_str, -1) = ".")
        num_str := SubStr(num_str, 1, -1)
    
    return num_str
}
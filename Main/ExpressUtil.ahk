#Requires AutoHotkey v2.0
; 新增：使用表达式解析器计算（支持括号）
GetExpressionResult(Expression, tableItem, tableIndex, &Res) {
    if (Expression == "")
        return false

    ; 替换表达式中的变量为实际值
    ProcessedExpr := GetReplaceVarText(tableItem, tableIndex, Expression)
    ; 计算表达式
    try {
        Res := EvaluateExpression(ProcessedExpr)
        return true
    } catch {
        ; 解析失败，回退到简单计算
        return false
    }
}

; 新增：表达式计算器（支持括号运算）- 使用词法分析+递归下降解析
EvaluateExpression(expr) {
    ; 预处理：去除空格
    expr := RegExReplace(expr, "\s+", "")

    ; 如果表达式为空，返回0
    if (expr == "")
        return 0

    ; 词法分析：将表达式分解成token
    tokens := Tokenize(expr)
    if (tokens.Length == 0)
        return 0

    ; 递归下降解析
    pos := 1
    result := ParseAddSub(tokens, &pos)
    resultStr := TrimZeros(result)

    return resultStr
}

; 词法分析：将表达式分解成token
Tokenize(expr) {
    tokens := []
    pos := 1
    len := StrLen(expr)

    while (pos <= len) {
        char := SubStr(expr, pos, 1)
        ; 识别数字（整数或小数）
        if (RegExMatch(char, "\d")) {
            numStr := ""
            while (pos <= len && RegExMatch(SubStr(expr, pos, 1), "[\d\.]")) {
                numStr .= SubStr(expr, pos, 1)
                pos++
            }
            tokens.Push(numStr)
            continue
        }

        ; 识别运算符和括号
        if (InStr("+-*/%^()", char)) {
            tokens.Push(char)
            pos++
            continue
        }

        ; 未知字符，跳过
        pos++
    }

    return tokens
}

; 解析加减（最低优先级）
ParseAddSub(tokens, &pos) {
    value := ParseMulDiv(tokens, &pos)

    while (pos <= tokens.Length && InStr("+-", tokens[pos])) {
        op := tokens[pos]
        pos++
        next := ParseMulDiv(tokens, &pos)

        if (op == "+")
            value := Round(value + next, 6)
        else
            value := Round(value - next, 6)
    }

    return value
}

; 解析乘除模（中等优先级）
ParseMulDiv(tokens, &pos) {
    value := ParsePower(tokens, &pos)

    while (pos <= tokens.Length && InStr("*/%", tokens[pos])) {
        op := tokens[pos]
        pos++
        next := ParsePower(tokens, &pos)

        if (op == "*")
            value := Round(value * next, 6)
        else if (op == "/")
            value := Round(value / next, 6)
        else if (op == "%")
            value := Round(Mod(value, next), 6)
    }

    return value
}

; 解析乘方（高优先级）
ParsePower(tokens, &pos) {
    value := ParseAtom(tokens, &pos)

    if (pos <= tokens.Length && tokens[pos] == "^") {
        pos++
        next := ParsePower(tokens, &pos)  ; 右结合
        value := Round(value ** next, 6)
    }

    return value
}

; 解析原子（数字或括号表达式）
ParseAtom(tokens, &pos) {
    if (pos > tokens.Length)
        return 0

    token := tokens[pos]

    ; 如果是数字
    if (RegExMatch(token, "^[\d\.]+$")) {
        pos++
        return token
    }

    ; 如果是左括号
    if (token == "(") {
        pos++  ; 跳过 '('
        value := ParseAddSub(tokens, &pos)  ; 递归解析括号内表达式
        if (pos <= tokens.Length && tokens[pos] == ")")
            pos++  ; 跳过 ')'
        return value
    }

    ; 处理带符号的数字（负数、正数）
    ; 注意：这里只在括号内或表达式的独立位置才会处理符号
    if (token == "+" || token == "-") {
        sign := token == "+" ? 1 : -1
        pos++
        value := ParseAtom(tokens, &pos)  ; 递归获取数字或括号表达式
        return sign * value
    }

    ; 未知token，跳过
    pos++
    return 0
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

    num_str := num_str == "" ? "0" : num_str

    return num_str
}

#Requires AutoHotkey v2.0

; RingBuffer for Single Producer / Single Consumer
; Layout:
; offset 0:  head (uint)
; offset 64: tail (uint)
; offset 128: buf
class RingBuffer {
    __New(ptr, size) {
        this.base := ptr
        this.size := size
        this.headPtr := ptr
        this.tailPtr := ptr + 64
        this.bufPtr := ptr + 128
        this.cap := size - 128
    }

    GetHead() => NumGet(this.headPtr, 0, "UInt")
    SetHead(v) => NumPut("UInt", v, this.headPtr)
    
    GetTail() => NumGet(this.tailPtr, 0, "UInt")
    SetTail(v) => NumPut("UInt", v, this.tailPtr)

    Push(id, str) {
        len := (StrLen(str) + 1) * 2
        total := 8 + len  ; 4 bytes ID + 4 bytes len + string bytes

        head := this.GetHead()
        tail := this.GetTail()

        ; check available space
        avail := (tail > head) ? (tail - head) : (this.cap - (head - tail))
        if (avail <= total + 8) ; keep some slack
            return false

        pos := Mod(head, this.cap)

        ; if it doesn't fit at the end of buffer, insert dummy marker (-1) and wrap around
        if (pos + total > this.cap) {
            if (this.cap - pos >= 4) {
                NumPut("Int", -1, this.bufPtr, pos)
            }
            head += this.cap - pos
            pos := 0
            
            ; Re-check space after wrap
            avail := (tail > head) ? (tail - head) : (this.cap - (head - tail))
            if (avail <= total + 8)
                return false
        }

        NumPut("UInt", id, this.bufPtr, pos)
        NumPut("UInt", len, this.bufPtr, pos + 4)
        StrPut(str, this.bufPtr + pos + 8)

        DllCall("Kernel32\MemoryBarrier")
        this.SetHead(head + total)
        return true
    }

    Pop(&id, &str) {
        head := this.GetHead()
        tail := this.GetTail()

        if (tail >= head)
            return false

        pos := Mod(tail, this.cap)
        
        ; Read ID, which might be unsigned except for our -1 marker.
        ; NumGet "Int" for -1 check
        id_signed := NumGet(this.bufPtr, pos, "Int")

        if (id_signed == -1) {
            ; Wrap around marker
            tail += (this.cap - pos)
            this.SetTail(tail)
            return this.Pop(&id, &str)
        }

        id := NumGet(this.bufPtr, pos, "UInt")
        len := NumGet(this.bufPtr, pos + 4, "UInt")
        str := StrGet(this.bufPtr + pos + 8, len // 2)

        DllCall("Kernel32\MemoryBarrier")
        this.SetTail(tail + 8 + len)
        return true
    }
}

; Event Helpers
CreateEvent(name) {
    return DllCall("CreateEvent", "ptr", 0, "int", false, "int", false, "str", name, "ptr")
}

OpenEvent(name) {
    return DllCall("OpenEvent", "uint", 0x1F0003, "int", 0, "str", name, "ptr")
}

SetEvent(h) {
    DllCall("SetEvent", "ptr", h)
}

ResetEvent(h) {
    DllCall("ResetEvent", "ptr", h)
}

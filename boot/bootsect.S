entry start
start:
        mov ax, 0x7c0
        mov ds, ax
        mov ax, 0x900
        mov cx, #256     # 移动256个字，即512个字节，为bootsect的大小
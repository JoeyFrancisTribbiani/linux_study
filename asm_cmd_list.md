## 移动指令
`movs/movw` 移动内存地址ds:si处的一个字到es:di处;如果设置了direction flag, 那么si与di会在该指令执行后减小1, 如果没有设置direction flag, 那么si与di的值会增加1.

`rep` 重复字符串操作前缀,用于重复一条紧跟着的字符串指令，并把(e)cx寄存器的值减去一,直到(e)cx为0

## 移动指令
`movs/movw` 移动内存地址ds:si处的一个字到es:di处;如果设置了direction flag, 那么si与di会在该指令执行后减小1, 如果没有设置direction flag, 那么si与di的值会增加1.

`rep` 重复字符串操作前缀,用于重复一条紧跟着的字符串指令，并把(e)cx寄存器的值减去一,直到(e)cx为0

`jnc` Jump if Not Carry,无进位跳转，比较标志寄存器的进位标志位CF，如果等于0就跳转

`seg` 表明紧跟着它的下一句指令将使用段超越。寄存器的默认组合，比如指令 `mov [si],ax` 表示将ax中的内容存入ds:si指向的内存单元，也就是说在寄存器间接寻址的情况下,以si间接寻址时总是默认以ds为相应的段地址寄存器。同样 di是以es为默认的段地址寄存器。

`lgs` 传送目标指针,把指针内容装入GS.例: LGS DI,string ;把段地址:偏移地址存到GS:DI.

`cld` CLear Direction flag,将标志寄存器Flag的方向标志位DF清零，在字串操作中使变址寄存器si或di的地址指针自动增加，字串处理从前往后.
`std` SeT Direction flag,将标志寄存器Flag的方向标志位DF置位，在字串操作中使变址寄存器si或di的地址指针自动减少，字串处理从后往前.

`cli` Clear Interrupt,将标志寄存器Flag的中断标志位IF清零，禁止中断发生.
`sti` SeT Interrupt,将标志寄存器Flag的中断标志位IF置位，允许中断发生.

`lodsb/lodsw` 这是块装入指令,把SI指向的存储单元读入累加器,LODSB就读入AL,LODSW就读入AX中,然后SI自动增加或减小1或2.
块装入指令常常用来对数组或字符串中的元素逐个进行处理.例如,假设以下的array为程序中定义的数组,items为数组长度,那么如下方法遍历此数组.
``` Assembly 
xor di,di
lea si,array
cld
c50:
lodsd
inc di
cmp di,items
jbe c50
```

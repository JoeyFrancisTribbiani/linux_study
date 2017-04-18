BOOTSEG = 0X7c0
INITSEG = 0x900
SETUPLEN = 4
SYSSEG = DEF_SYSSEG

entry start
start:
        mov ax,#BOOTSEG
        mov ds,ax
        mov ax,#INITSEG
        mov es,ax
        sub si,si
        sub di,di
        mov cx,#256             # 移动256个字，即512个字节，为bootsect的大小

        rep
        movw

        jmpi go,INITSEG         # 此时cs变为 #INITSEG,0x900

go:
        mov ax,cs
        mov dx,#0xfef4

        mov ds,ax
        mov es,ax
        push    ax              # 保存段地址

        mov ss,ax               # 堆栈段=代码段=数据段
        mov sp,dx               # 栈指针指向栈顶

! 重置最大扇区数
        push    #0              # fs:辅助段寄存器,这里用fs:bx来存放软驱参数表源地址
        pop     fs
        mov bx,#0x78            # fx:bx=0x78

        seg fs
        lgs si,(bx)             # seg表示下一语句中的操作数在fs段寄存器所指的段中，
                                # 这里把fs:bx处的表地址放到gs:si处作为原地址，寄存器对es:di=0x9000:0xfef4为目的地址

        mov di,dx 
        mov cx,#6               # 复制12字节，与rep指令配合
        cld
        rep                     # 重复执行下一语句，并使cx减一直至cx=0
        seg gs
        movw                    # 默认是将ds:si处的一个字移动到es:di，并将si和di按方向位+/-2，这里使用段超越，因此操作数是gs:si，目的地址不变仍是es:di
        
        mov di,dx               # 之前di变化了，重置为目的地址(复制的表的新地址)
        movb    4(di),*18       # 将新表中偏移4处的最大扇区数修改为18



load_setup:
        # 读盘2-4扇区(setup模块)到0x90200
        xor dx,dx               # DL:驱动器，00H~7FH:软盘；08H~0FFH:硬盘
        mov ax,#0x0200+SETUPLEN          # AH:入口参数=读取磁盘内容，AL:扇区数=4
        mov cx,#0x0002          # CH:柱面=0,CL:扇区=2
        mov bx,#0x0200          # ES:BX:缓冲区的地址
        int 0x13                # CF=0,操作成功,AH=00H,AL=传输的扇区数;CF=1,操作失败,AH=状态代码
        jnc ok_load_setup       # 成功就跳转，失败就重置磁盘重试

        push    ax
        call    print_nl
        mov bp,sp
        call    print_hex
        pop     ax

        xor ah,ah               # AH:入口参数=磁盘系统复位
        xor dl,dl               # DL:驱动器，00H~7FH:软盘；08H~0FFH:硬盘
        int 0x13
        j   load_setup

ok_load_setup:
        # 获取硬盘参数
        # waiting fix

! 打印加载消息
        mov ah,#0x03            # AH:入口参数=03h,文本坐标下读取光标各种信息
        xor bh,bh               # BH:显示页码
        int 0x10                # 出口参数：CH=光标的起始行，CL=光标终止行，DH=行，DL=列

        mov ax,#0x1301          # AH:入口参数=13H，在Teletype模式下显示字符串
        mov cx,#9               # CX:显示字符串长度
        mov bx,#0x0007          # BH:页码，BL:属性
        mov bp,#msg1            # ES:BP=显示字符串的地址
        int 0x10

! 开始加载system模块
        mov ax,#SYSSEG
        mov es,ax               # 将system模块读到0x010000开始处
        call    read_it
        call    kill_motor
        call    print_nl

! 设置根文件系统
#include <linux/config.h>
SYSSIZE = DEF_SYSSIZE
.globl begtext, begdata, begbss, endtext, enddata, endbss
.text
begtext:
.data
begdata:
.bss
begbss:
.text

SETUPLEN = 4				! nr of setup-sectors
BOOTSEG  = 0x07c0			! original address of boot-sector
INITSEG  = DEF_INITSEG			! we move boot here - out of the way
SETUPSEG = DEF_SETUPSEG			! setup starts here
SYSSEG   = DEF_SYSSEG			! system loaded at 0x10000 (65536).
ENDSEG   = SYSSEG + SYSSIZE		! where to stop loading

! ROOT_DEV & SWAP_DEV are now written by "build".
ROOT_DEV = 0
SWAP_DEV = 0

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
        movb    4(di),*18       # 将新表中偏移4处(es:di+4)的最大扇区数修改为18

        seg fs
        mov (bx),di
        seg fs
        mov 2(bx),es

        pop ax
        mov fs,ax
        mov gs,ax

        xor ah,ah
        xor dl,dl
        int 0x13

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
        xor	dl,dl
	mov	ah,#0x08		! AH=8 is get drive parameters
	int	0x13
	xor	ch,ch
	seg cs
	mov	sectors,cx
	mov	ax,#INITSEG
	mov	es,ax
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
        seg cs
        mov ax,root_dev
        or ax,ax
        jne root_defined

        seg cs
        mov bx,sectors
        mov ax,0x0208
        cmp bx,#15
        je      root_defined
        mov ax,0x021c
        cmp bx,#18
        je      root_defined

root_undefined:
        jmp     root_undefined

root_defined:
        mov root_dev,ax

        jmpi    0,SETUPSEG

sread:  .word 1+SETUPLEN
head:   .word 0
track:  .word 0

read_it:
        mov ax,es
        test    ax,0x0fff
        jnz     die

die:    jmp     die

        xor bx,bx

rp_read:
        mov ax,es
        cmp ax,#ENDSEG
        jb  ok1_read

        ret

ok1_read:
        seg cs
        mov ax,sectors
        sub ax,sread
        mov cx,ax
        shl cx,#9
        add cx,bx
        jnc ok2_read
        je  ok2_read
        xor ax,ax
        sub ax,bx
        shr ax,#9

ok2_read:
	call read_track
	mov cx,ax
	add ax,sread
	seg cs
	cmp ax,sectors
	jne ok3_read
	mov ax,#1
	sub ax,head
	jne ok4_read
	inc track

ok4_read:
	mov head,ax
	xor ax,ax

ok3_read:
	mov sread,ax
	shl cx,#9
	add bx,cx
	jnc rp_read
        mov ax,es
	add ah,#0x10
	mov es,ax
	xor bx,bx
	jmp rp_read

read_track:
	pusha
	pusha	
	mov	ax, #0xe2e 	! loading... message 2e = .
	mov	bx, #7
 	int	0x10
	popa		

	mov dx,track
	mov cx,sread
	inc cx
	mov ch,dl
	mov dx,head
	mov dh,dl
	and dx,#0x0100
	mov ah,#2
	
	push	dx				! save for error dump
	push	cx
	push	bx
	push	ax

	int 0x13
	jc bad_rt
	add	sp, #8   	
	popa
	ret

bad_rt:	push	ax				! save error code
	call	print_all			! ah = error, al = read
	
	
	xor ah,ah
	xor dl,dl
	int 0x13
	

	add	sp, #10
	popa	
	jmp read_track


print_all:
        mov	cx, #5		! error code + 4 registers
	mov	bp, sp	

print_loop:
	push	cx		! save count left
	call	print_nl	! nl for readability
	jae	no_reg		! see if register name is needed
	
	mov	ax, #0xe05 + 0x41 - 1
	sub	al, cl
	int	0x10

	mov	al, #0x58 	! X
	int	0x10

	mov	al, #0x3a 	! :
	int	0x10

no_reg:
	add	bp, #2		! next register
	call	print_hex	! print it
	pop	cx
	loop	print_loop
	ret

print_nl:
	mov	ax, #0xe0d	! CR
	int	0x10
	mov	al, #0xa	! LF
	int 	0x10
	ret

/*
 *	print_hex is for debugging purposes, and prints the word
 *	pointed to by ss:bp in hexadecmial.
*/

print_hex:
	mov	cx, #4		! 4 hex digits
	mov	dx, (bp)	! load word into dx
print_digit:
	rol	dx, #4		! rotate so that lowest 4 bits are used
	mov	ah, #0xe	
	mov	al, dl		! mask off so we have only next nibble
	and	al, #0xf
	add	al, #0x30	! convert to 0 based digit, '0'
	cmp	al, #0x39	! check for overflow
	jbe	good_digit
	add	al, #0x41 - 0x30 - 0xa 	! 'A' - '0' - 0xa

good_digit:
	int	0x10
	loop	print_digit
	ret


/*
 * This procedure turns off the floppy drive motor, so
 * that we enter the kernel in a known state, and
 * don't have to worry about it later.
 */
kill_motor:
	push dx
	mov dx,#0x3f2
	xor al, al
	outb
	pop dx
	ret

sectors:
	.word 0

msg1:
	.byte 13,10
	.ascii "Loading"

.org 506
swap_dev:
	.word SWAP_DEV
root_dev:
	.word ROOT_DEV
boot_flag:
	.word 0xAA55

.text
endtext:
.data
enddata:
.bss
endbss:
bits 16
org 0x7C00


	cli
mov ah , 0x02
mov al ,8
mov dl , 0x80
mov ch , 0
mov dh , 0
mov cl , 2
mov bx, START
int 0x13
jmp START



times (510 - ($ - $$)) db 0
db 0x55, 0xAA
START:
cli
	
	xor ax , ax  
	mov ss , ax 
	mov sp , 0xffff
        
	xor ecx,ecx
        JMBAK:
        mov edi, [address+ecx*4]
        mov esi,edi
        mov ebp,esi
        add ebp,0xFA0
        SETNULL:
        mov byte[esi],0
        mov byte[esi+1],0x0F
        add esi,2
        cmp esi,ebp
        jle SETNULL
        mov esi,edi
        add esi,0x1000
        inc ecx
        cmp ecx,8
        jl JMBAK
        mov edi,0xB8000
        mov bx,[Table]
	;WRITE YOUR CODE HERE
        mov ah,0
        mov al,03h
        int 0x10
        mov ch, 0
        mov cl, 7
        mov ah, 1
        int 10h 
        mov bh,0
        mov dh,0
        mov dl,0
        mov ah,2
        int 10h
        mov AL,0xF4 ; initialization
        call WriteCheck
        jmp Main
        
  WriteCheck:
        mov ah,al
        call repeatedCheck
        mov al,0xD4
        out 0x64,al
        call repeatedCheck
        mov al,ah
        out 0x60,AL;
        call ReadCheck
   Again:     
        in AL,0x64
        and AL , 0x01 ; Acknowledgement
        jz Again
        ret 
               
                           
ReadCheck:
        in al,0x64
        and al,0x01
        jz ReadCheck
        ret


repeatedCheck: 
        mov ecx,1000
        L:
        in al,0x64
        and al,00000010b	
        jz YouCanSend
        loop L
        YouCanSend:
        ret 
readFromMouse: 
      mov ecx,1000
      ReadAg:
      in AL,0x64
      test AL,0x01
      jnz enough
      loop ReadAg
      enough:
      IN AL,0x60
      ret
      
             
   Main:     
     ;call SetCursor
     in al,0x64   
     test al,0x01
     jz Main
     test al,00100000b;0x20
     jz Read 
     ;test al,0x01
;     jz Main
     call readFromMouse; first Byte
     mov [firstByte],AL
     
     
     xor ax,ax
     xor cx,cx
     ; Delta X :
     call readFromMouse
     movsx cx,al
     mov ax,cx
     sar ax,2; div by 4
     add [X], ax
      
     
     xor ax,ax
     xor dx,dx
     ; Delta Y
     call readFromMouse
     movsx dx,al
     mov ax,dx
     neg ax
     sar ax,2 ; div by 4
     add [Y], ax
    
     mov ax,[X]
     shr ax,2 ; div by 4
     ; row now in al
     mov dx,[Y]
     shr dx,3 ; div by 8
     mov dh,dl
     ; now column in dh
     mov dl,al
     cmp dl,0
     jg nn2
     mov dl,0
     jmp xInside
     nn2:
     cmp dl,79
     jl xInside
     mov dl,79
     xInside:
     cmp dh,0
     jg nn3
     mov dh,0
     jmp yInside
     nn3:
     cmp dh,24
     jl yInside
     mov dh,24
     yInside:
     mov bh,[PageNumber]
     mov ah,0x02
     int 0x10
     test byte[firstByte], 0x01; left button
     jnz Ma
     jmp Main
     
     
     
     
     Ma:
     
     test byte[STATUS],0x04
     jz rvon
     call RemoveShading
     rvon:
     call getEDI
     mov edi,eax
     mov [boundedBy],edi
     jmp Main
     
     
     
     
     
Read:
in al,0x60
;###SPECIAL_CASES###

CTRL:
cmp al,0x1D
jne CTRLBR
ctrl:
or byte[STATUS],0x08 ; set
jmp Main

CTRLBR:
cmp al,0x9D
jne JBR
ctrlbr:
and byte[STATUS],0xF7 ; reset
jmp Main

JBR:
test byte[STATUS],0x08 ; check control status
jz SHIFT ; continue
;here when Control_Is_Pressed
cmp al,0x2E ; C
jne con2
test byte[STATUS],0x04 ; check shaded string
jz Main
call COPY
jmp Main
con2:
cmp al,0x2F ; V
jne con3
test byte[STATUS],0x04 ; check shaded string
jz jmpthere
call DeleteFirst
jmpthere:
call PASTE
jmp Main

con3:
cmp al,0x2D ; X
jne con4
test byte[STATUS],0x04 ; check shaded string
jz Main
call COPY
call DeleteFirst
jmp Main

con4:
cmp AL , 0x1E ; A
jne con5
mov cl,[PageNumber]
and ecx,0xFF
mov edi,[limits+ecx*4]
mov [boundedBy],edi
CTRLA:
cmp byte[edi],0
je OVERCOME
or byte[edi+1],0x30 ; 0011 0000
OVERCOME:
add edi,2   
mov ebp,[limits+ecx*4]  
add ebp,0xFA0        
cmp edi,ebp
jle CTRLA
LP_1:
sub edi,2
cmp byte[edi-2],0
je LP_1
mov [boundedBy+4],edi
or byte[STATUS],0x04 ; set shaded status
jmp Main
con5:
cmp al,0x2C ; Z
jne con6
mov cl,[PageNumber]
and ecx,0xFF
mov edi,[limits+ecx*4]
mov [boundedBy],edi
add edi,0xFA0
mov [boundedBy+4],edi
mov ecx,25*80
mov [length],ecx
xor ecx,ecx
mov esi,[boundedBy]
AD1_:
mov al,[PREVIOUS_STATUS + ecx] ; 
mov [esi+ecx*2],al
inc ecx
cmp ecx,[length]
jl AD1_
LP_2:
sub edi,2
cmp byte[edi-2],0
je LP_2
jmp Main
con6:
cmp al,0x1F ; S
jne Main
push edi
mov cl,[PageNumber]
and ecx,0xFF
mov edi,[limits+ecx*4]
mov [boundedBy],edi
add edi,0xFA0
mov [boundedBy+4],edi
mov ecx,25*80
mov [length],ecx
xor ecx,ecx
mov esi,[boundedBy]
AD_:
mov al,[esi+ecx*2]
mov [PREVIOUS_STATUS + ecx],al
inc ecx
cmp ecx,[length]
jl AD_
pop edi
jmp Main
SHIFT:
cmp al,0x2A ; LSH make
je shift
cmp al,0x36 ;RSH make
je shift
SHIFTBREAK:
cmp al,0xAA;R SH break
jne SHIFTBREAK2
mov bx,ScanCodeTable
mov [Table],bx
jmp Main
SHIFTBREAK2:
cmp al,0xB6;L SH break
jne CAPSLOCK
mov bx,ScanCodeTable
mov [Table],bx
jmp Main
CAPSLOCK: ; make
cmp al,0x3A
jne NUMLOCK
xor byte[STATUS],0x02;toggle  0000 0010
jmp Main
NUMLOCK: ; make
cmp al,0x45
jne ESCAPE
xor byte[STATUS],0x01; toggle  0000 0001
jmp Main
ESCAPE:
cmp al,0x01
je Main
ALT: ; to change color of shaded string
; ALT + R = red 
; ALT + B = blue
; ALT + Y = yellow
; ALT + G = green
; ALT + W = white
cmp al,0x38
jne ALTBR
alt:
or byte[STATUS],0x10 ; set    0001 0000  
jmp Main
ALTBR:
cmp al,0xB8
jne CHECK_ALT
alt_br:
and byte[STATUS],0xEF ; reset 1110 1111
jmp Main


CHECK_ALT:
test byte[STATUS],0x10 ; alt
jz Arrows
RED:
cmp al,0x13 ; r
jne BLUE
mov cl,0x04
jmp there
BLUE:
cmp al,0x30 ; b
jne GREEN
mov cl,0x01
jmp there
GREEN:
cmp al,0x22 ; g
jne YELLOW
mov cl,0x0A
jmp there
YELLOW: 
cmp al,0x15 ; y
jne WHITE
mov cl,0x0E
jmp there
WHITE:
cmp al,0x11 ; w
jne Main
mov cl,0x0F
there:
call changeColor
jmp Main

Arrows: ; [0xE0 arrow] or [0xE0 0xAA 0xE0 arrow] or [0xE0 0xB6 0xE0 arrow]
cmp AL,0xE0
jne BKSP
cAg:
in al,0x64
and al,0x01
jz cAg 	
in al,0x60
cmp AL,0xAA
je SHADE  
cmp AL,0xB6
je SHADE


LEFT:
cmp al,0x4B ; Left Arrow
jne RIGHT
left:
test byte[STATUS],0x04 ; SHADED
jz LM1
call RemoveShading
mov edi,[boundedBy]
jmp Main
LM1:
mov cl,[PageNumber]
and ecx,0xFF
cmp edi,[limits+ecx*4]
je Main
mov eax,edi
sub eax,[limits+ecx*4]
mov ecx,160
xor edx,edx
div ecx
cmp edx,0
jne NotFirst
RepeatThat:
sub edi,2
mov eax,edi
mov cl,[PageNumber]
and ecx,0xFF
sub eax,[limits+ecx*4]
mov ecx,160
xor edx,edx
div ecx
cmp edx,0
je bbb
cmp byte[edi-2],0
je RepeatThat
bbb:
jmp Main


NotFirst:
sub edi,2
jmp Main
RIGHT:
cmp al,0x4D ; Right Arrow
jne UP
right:
test byte[STATUS],0x04 ; SHADED
jz LM2
call RemoveShading
mov edi,[boundedBy+4]
jmp Main
LM2:
mov cl,[PageNumber]
and ecx,0xFF
mov ebp,[limits+ecx*4]
add ebp,0xFA0
cmp edi,ebp
je Main
cmp byte[edi+2],0
je nextline
add edi,2
jmp Main
nextline:
xor edx,edx
mov eax,edi
mov cl,[PageNumber]
and ecx,0xFF
sub eax,[limits+ecx*4]
mov ecx,0xA0 ; 160
div ecx
sub edx,0xA0
neg edx
cmp byte[edi+edx],0
je Main
add edi,edx
jmp Main
UP:
cmp al,0x48 ; up
jne DOWN
up:
test byte[STATUS],0x04 ; SHADED
jz LM3
call RemoveShading
LM3:
mov cl,[PageNumber]
and ecx,0xFF
mov ebp,[limits+ecx*4]
add ebp,0xA0
cmp edi,ebp ; first line
jl Main
sub edi,0xA0 ;80 * 2
cmp byte[edi-2],0
jne Main
RepeatThat2:
mov eax,edi
mov cl,[PageNumber]
and ecx,0xFF
sub eax,[limits+ecx*4]
mov ecx,160
xor edx,edx
div ecx
cmp edx,0
je Main
sub edi,2
cmp byte[edi-2],0
je RepeatThat2
DOWN:
cmp al,0x50 ;down
jne R_ALT
down:
test byte[STATUS],0x04 ; SHADED
jz LM4
call RemoveShading
LM4:
mov cl,[PageNumber]
and ecx,0xFF
mov ebp,[limits+ecx*4]
add ebp,0xF00
cmp edi,ebp; last line
jge Main
add edi,0xA0
RepeatThat3:
mov eax,edi
mov cl,[PageNumber]
and ecx,0xFF
sub eax,[limits+ecx*4]
mov ecx,0xA0 ; 160
xor edx,edx
div ecx
cmp edx,0
je Main
sub edi,2
cmp byte[edi-2],0
je RepeatThat3
jmp Main

R_ALT:
cmp al,0x38
jne R_ALT_BR
jmp alt
R_ALT_BR:
cmp al,0xB8
jne Del
jmp alt_br
Del:
;;;;
cmp AL,0x53
jne HOME
del:
test byte[STATUS],0x04 ; SHADED
jz LMEA
call DeleteFirst
jmp Main
LMEA:
mov ebp,edi
HA2:
mov dx,[edi+2] ; char + color
mov [edi],dx
add edi,2
cmp dl,0
jne HA2
mov edi,ebp
jmp Main

HOME:
cmp AL,0x47
jne END
home:
test byte[STATUS],0x04 ; SHADED
jz LM5
call RemoveShading
LM5:
xor edx,edx
mov eax,edi
mov cl,[PageNumber]
and ecx,0xFF
sub eax,[limits+ecx*4]
mov ecx,0xA0
div ecx
sub edi,edx
jmp Main
END:
cmp AL,0x4F
jne CTRL2
end:
test byte[STATUS],0x04 ; SHADED
jz LM6
call RemoveShading
LM6:
xor edx,edx
mov eax,edi
mov cl,[PageNumber]
and ecx,0xFF
sub eax,[limits+ecx*4]
mov ecx,0xA0
div ecx
sub edi,edx
add edi,0x9E
jmp Main

CTRL2:
cmp al,0x1D
je ctrl
cmp al,0x9D
je ctrlbr
cmp al,0x51
je PAGEDOWN
cmp al,0x49
je PAGEUP
cmp al,0x1C
je entr
jmp Main
;####### 0xE0




BKSP: 
cmp al,0x0E ; BKSP
jne TAB
test byte[STATUS],0x04 ; SHADED
jz LMEA2
call DeleteFirst
jmp Main
LMEA2:
mov cl,[PageNumber]
and ecx,0xFF
cmp edi,[limits+ecx*4]
je Main
mov ebp,edi
HA:
mov dx,[edi]
mov [edi-2],dx
add edi,2
cmp dl,0
jne HA
mov edi,ebp
sub edi,2
cmp byte[edi-2],0
jne Main
mov eax,edi
mov cl,[PageNumber]
and ecx,0xFF
sub eax,[limits+ecx*4]
mov ecx,160
xor edx,edx
div ecx
cmp edx,0
je Main
jmp LMEA2
TAB:
cmp al,0x0F ; tab ******
jne ENTR
mov ecx,8
LP_0:
push ecx
mov al,0x20 ; space
call Insert
pop ecx
loop LP_0
jmp Main
ENTR:
cmp al,0x1C ; enter
jne NEXT2
entr:
xor edx,edx
mov eax,edi
mov cl,[PageNumber]
and ecx,0xFF
sub eax,[limits+ecx*4]
mov ecx,0xA0
div ecx
sub edx,0xA0
neg edx
cmp byte[edi],0
jne that
add edi,edx
jmp Main
that:
mov esi,edi
add edi,edx
push edi
mov ecx,edx
LOO:
push ecx
mov al,[esi]
cmp al,0
je goThere
mov byte[esi],0
call Insert
add esi,2
pop ecx
loop LOO
sub esp,4
goThere:
add esp,4
pop edi
jmp Main
NEXT2:
cmp AL,0x52
jne NEXT3
test byte[STATUS],0x01
jz Main
mov AL,'0'
jmp print
NEXT3:
cmp al,0x4F
jne NEXT4
test byte[STATUS],0x01
jz end
mov AL,'1'
jmp print
NEXT4:
cmp al,0x50
jne NEXT5
test byte[STATUS],0x01
jz down
mov AL,'2'
jmp print
NEXT5:
cmp al,0x51
jne NEXT6
test byte[STATUS],0x01
jz PAGEDOWN
mov AL,'3'
jmp print

NEXT6:
cmp al,0x4B
jne NEXT7
test byte[STATUS],0x01
jz left
mov AL,'4'
jmp print
NEXT7:
cmp al,0x4C
jne NEXT8
test byte[STATUS],0x01
jz Main
mov AL,'5'
jmp print
NEXT8:
cmp al,0x4D
jne NEXT9
test byte[STATUS],0x01
jz right
mov AL,'6'
jmp print
NEXT9:
cmp al,0x47
jne NEXT10
test byte[STATUS],0x01
jz home
mov AL,'7'
jmp print
NEXT10:
cmp al,0x48
jne NEXT11
test byte[STATUS],0x01
jz up
mov AL,'8'
jmp print
NEXT11:
cmp al,0x49
jne NEXT12
test byte[STATUS],0x01
jz PAGEUP
mov AL,'9'
jmp print
NEXT12:
cmp al,0x53
jne NEXT13
test byte[STATUS],0x01
jz del
mov al,'.'
jmp print
NEXT13:
cmp al,0x37
jne NEXT14
test byte[STATUS],0x01
jz Main
mov al,'*'
jmp print
NEXT14:
cmp al,0x4A
jne NEXT15
test byte[STATUS],0x01
jz Main
mov al,'-'
jmp print
NEXT15:
cmp al,0x4E
jne F_KEYS
test byte[STATUS],0x01
jz Main
mov al,'+'
jmp print

F_KEYS:
cmp al,0x3B ; F1
jl CHARS
cmp al,0x42 ; F8
jg CHARS
sub al,0x3B ; get page index
call SetPage
jmp Main
CHARS:

cmp al,0x80
jnb Main
mov bx,[Table]
xlat
test byte[STATUS],0x02 ; CapsLock
jz print
cmp al,'a'
jb d
cmp al,'z'
ja d
sub AL,0x20 ; small to cap
jmp print
d:
cmp al,'A'
jb print
cmp al,'Z'
ja print
add AL,0x20 ; cap to small
print:
test byte[STATUS],0x04 ; shaded
jz AMHB
and byte[STATUS],0xFB
call DeleteFirst
mov [edi],al
add edi,2
jmp Main
AMHB:
call Insert

jmp Main
DeleteFirst:
mov esi,[boundedBy]
mov edi,[boundedBy+4]
mov ecx,edi
sub ecx,esi
shr ecx,1
OuterLp:
mov ebp,edi
cloop:
mov dl,[edi]
mov [edi-2],dl
mov byte[edi-1],0x0F
add edi,2
cmp dl,0
jne cloop
mov edi,ebp
sub edi,2
loop OuterLp
and byte[STATUS],0xFB
ret

RemoveShading:
mov eax,[boundedBy]
LPS:
and byte[eax+1],0x0F
add eax,2
cmp eax,[boundedBy+4]
jle LPS
and byte[STATUS],0xFB 
ret

shift:
mov bx,ScanCodeTableSH
mov [Table],bx
jmp Main

SHADE: ;[0xE0 0xAA 0xE0 arrow] or [0xE0 0xB6 0xE0 arrow]
test byte[STATUS],0x04;SHADED
jnz AAG
mov [boundedBy],edi
mov [boundedBy+4],edi
AAG:
in al,0x64
and al,0x01
jz AAG
in al,0x60
cmp AL,0xE0
jne Main
AAG2:
in al,0x64
and al,0x01
jz AAG2
in al,0x60
LEFTSH:
cmp al,0x4B ; Left Arrow
jne RIGHTSH
sub edi,2
cmp edi,[boundedBy]
jle this
mov [boundedBy+4],edi
cmp edi,[boundedBy]
jne VV
je VW
this:
mov [boundedBy],edi
cmp edi,[boundedBy+4]
jne VV
VW:
and byte[STATUS],0xFB ; reset
jmp Main
VV:
or byte[STATUS],0x04 ; set
call SetColor
jmp Main
RIGHTSH:
cmp al,0x4D ; Right Arrow
jne UPSH
call SetColor
add edi,2
cmp edi,[boundedBy+4]
jge aasa
mov [boundedBy],edi
cmp edi,[boundedBy+4]
jne VVc
je VVc2
aasa:
mov [boundedBy+4],edi
cmp edi,[boundedBy]
jne VVc
VVc2:
and byte[STATUS],0xFB ; reset
jmp Main
VVc:
or byte[STATUS],0x04 ; set
jmp Main
UPSH:
cmp al,0x48 ; up
jne DOWNSH
cmp byte[edi-1],0x3F
jne contin
mov ecx,0x50
sub edi,2
mov edx,2
jmp LABEL
contin:
mov ecx,0x50 ;
xor edx,edx
LABEL:
call SetColor
sub edi,2
loop LABEL
add edi,edx
cmp edi,[boundedBy]
jle CCC
mov [boundedBy+4],edi
cmp edi,[boundedBy]
jne VVe
je VVe2
CCC:
mov [boundedBy],edi
cmp edi,[boundedBy+4]
jne VVe
VVe2:
and byte[STATUS],0xFB ; reset
jmp Main
VVe:
or byte[STATUS],0x04 ; set
jmp Main
DOWNSH:
cmp al,0x50 ;down
jne Main
cmp byte[edi+3],0x3F
jne contin2
mov ecx,0x50
add edi,2
mov edx,2
jmp LABEL2
contin2:
mov ecx,0x50 ;
xor edx,edx
LABEL2:
call SetColor
add edi,2
loop LABEL2
sub edi,edx
cmp edi,[boundedBy+4]
jge DDD
mov [boundedBy],edi
cmp edi,[boundedBy+4]
jne VVw
je VVw2
DDD:
mov [boundedBy+4],edi
cmp edi,[boundedBy]
jne VVw
VVw2:
and byte[STATUS],0xFB ; reset
jmp Main
VVw:
or byte[STATUS],0x04 ; set
jmp Main

PAGEDOWN:
mov al,[PageNumber]
cmp al,0
je Main
dec al
call SetPage
jmp Main
PAGEUP:
mov al,[PageNumber]
cmp al,7
je Main
inc al
call SetPage
jmp Main

 SetColor:
 cmp byte[edi],0
 jne COLR
 ret
 COLR:
test byte[edi+1],0x30
jnz unshade
or byte[edi+1],0x30
ret
unshade:
and byte[edi+1],0x0F
ret

Insert: ;AL in EDI
mov ebp,edi
mov dl,[edi]
mov dh,[edi+1]
HB:
mov cl,dl
mov ch,dh
add edi,2
mov dl,[edi]
mov dh,[edi+1]
mov [edi],cl
mov [edi+1],ch
cmp dl,0
jne HB
mov edi,ebp
mov [edi],al
inc edi
inc edi
ret

changeColor:
mov eax,[boundedBy]
oneMoreTime:

or cl,0x30 ; 
mov [eax+1],cl
add eax,2
cmp eax,[boundedBy+4]
jl oneMoreTime
ret
SetPage:
mov cl,[PageNumber]
and ecx,0xFF
mov [address+ecx*4],edi
and eax,0xFF
mov edi,[address+eax*4]
mov [PageNumber],al
mov ah,0x05
int 0x10
ret

SetCursor:
push ebx
mov eax,edi
mov cl,[PageNumber]
and ecx,0xFF
sub eax,[limits+ecx*4]
mov ecx,160
xor edx,edx
div ecx
mov dh,al ; row
; column is already in edx and so in dl, but multiplied by 2
shr dl,1 ; div by 2
mov ah,0x02
mov bh,[PageNumber]
int 0x10
pop ebx
ret


getEDI:
mov bh,[PageNumber]
mov ah,0x03
int 0x10
; row in dh and column in dl
movzx eax,dh
imul eax,160
and edx,0xFF ; dl
shl edx,1
add eax,edx
shr ebx,8
and ebx,0xFF ; bh 
add eax,[limits+ebx*4]
ret


COPY:

mov ecx,[boundedBy+4]
sub ecx,[boundedBy]; length
shr ecx,1 ; div by 2
mov [length],ecx
xor ecx,ecx
mov esi,[boundedBy]
AD:
mov ax,[esi+ecx*2]
mov [MyMemory + ecx*2],ax
inc ecx
cmp ecx,[length]
jl AD


ret

PASTE:

xor ecx,ecx
AD2:
mov ax,[MyMemory + ecx*2]
push ecx
call Insert
pop ecx
inc ecx
cmp ecx,[length]
jl AD2
ret

Table: dw ScanCodeTable
PageNumber: db 0
address: dd 0xB8000,0xB9000,0xBA000,0xBB000,0xBC000,0xBD000,0xBE000,0xBF000
limits: dd 0xB8000,0xB9000,0xBA000,0xBB000,0xBC000,0xBD000,0xBE000,0xBF000
ScanCodeTable:   db "//1234567890-=//qwertyuiop[]//asdfghjkl;'`/\zxcvbnm,.//// /"
ScanCodeTableSH: db '//!@#$%^&*()_+//QWERTYUIOP{}//ASDFGHJKL:"~/|ZXCVBNM<>?/// /' 
STATUS: db 0 ; X _ X _ X _ ALT _ CTRL _ SHADED _ CapsL _ NumL 
;  capslock at bit 1 and numlock at bit 0
;  bit 2 tells you if there is a shaded text (bounded between esi and edi)
; bit 3 for CTRL and bit 4 for ALT
length: dd 0
boundedBy: dd 0,0
MyMemory: times(25*80) db 0
PREVIOUS_STATUS: times(25*80) db 0
table: db '0123456789ABCDEF',0        
X: dw 0
Y: dw 0 ; initial values
Xp: dw 0
Yp: dw 0
firstByte: db 0


times (0x400000 - 512) db 0

db 	0x63, 0x6F, 0x6E, 0x65, 0x63, 0x74, 0x69, 0x78, 0x00, 0x00, 0x00, 0x02
db	0x00, 0x01, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
db	0x20, 0x72, 0x5D, 0x33, 0x76, 0x62, 0x6F, 0x78, 0x00, 0x05, 0x00, 0x00
db	0x57, 0x69, 0x32, 0x6B, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x78, 0x04, 0x11
db	0x00, 0x00, 0x00, 0x02, 0xFF, 0xFF, 0xE6, 0xB9, 0x49, 0x44, 0x4E, 0x1C
db	0x50, 0xC9, 0xBD, 0x45, 0x83, 0xC5, 0xCE, 0xC1, 0xB7, 0x2A, 0xE0, 0xF2
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
db	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
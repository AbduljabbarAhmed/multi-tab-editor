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
        mov edi, [address] ; default is first page
        mov bx,ScanCodeTable
checkAgain:
call SetCursor	
in al,0x64 ; XXXXXXXA
and al,0x01 ; 
jz checkAgain 	
Read:
in al,0x60
;###SPECIAL_CASES###

CTRL:
cmp al,0x1D
jne CTRLBR
ctrl:
or byte[STATUS],0x08 ; set
jmp checkAgain

CTRLBR:
cmp al,0x9D
jne SHIFT
ctrlbr:
and byte[STATUS],0xF7 ; reset
jmp checkAgain







SHIFT:
cmp al,0x2A ; LSH make
je shift
cmp al,0x36 ;RSH make
je shift
SHIFTBREAK:
cmp al,0xAA;R SH break
jne SHIFTBREAK2
mov bx,ScanCodeTable
jmp checkAgain
SHIFTBREAK2:
cmp al,0xB6;L SH break
jne CAPSLOCK
mov bx,ScanCodeTable
jmp checkAgain
CAPSLOCK: ; make
cmp al,0x3A
jne NUMLOCK
xor byte[STATUS],0x02;toggle  0000 0010
jmp checkAgain
NUMLOCK: ; make
cmp al,0x45
jne ESCAPE
xor byte[STATUS],0x01; toggle  0000 0001
jmp checkAgain
ESCAPE:
cmp al,0x01
je checkAgain
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
jmp checkAgain
ALTBR:
cmp al,0xB8
jne CHECK_ALT
alt_br:
and byte[STATUS],0xEF ; reset 1110 1111
jmp checkAgain


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
jne checkAgain
mov cl,0x0F
there:
call changeColor
jmp checkAgain

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
test byte[STATUS],0x08 ; control
jz norm
A2_Loop:
call left
mov cl,[PageNumber]
and ecx,0xFF
cmp edi,[limits+ecx*4]
je checkAgain
cmp byte[edi-2],0x20
je checkAgain
cmp byte[edi-2],','
je checkAgain
cmp byte[edi-2],';'
je checkAgain
cmp byte[edi-2],':'
je checkAgain
jmp A2_Loop
norm:
call left
jmp checkAgain


left:
test byte[STATUS],0x04 ; SHADED
jz LM1
call RemoveShading
mov edi,[boundedBy]
jmp checkAg
LM1:
mov cl,[PageNumber]
and ecx,0xFF
cmp edi,[limits+ecx*4]
je checkAg
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
je checkAg
cmp byte[edi-2],0
je RepeatThat
checkAg:
ret

NotFirst:
sub edi,2
jmp checkAg
RIGHT:
cmp al,0x4D ; Right Arrow
jne UP
test byte[STATUS],0x08 ; control
jz norm1

A1_Loop:
call right
cmp byte[edi],0x20
je checkAgain
cmp byte[edi],','
je checkAgain
cmp byte[edi],';'
je checkAgain
cmp byte[edi],':'
je checkAgain
cmp byte[edi],0
je checkAgain
jmp A1_Loop

norm1:
call right
jmp checkAgain

right:
test byte[STATUS],0x04 ; SHADED
jz LM2
call RemoveShading
mov edi,[boundedBy+4]
jmp checkA
LM2:
mov cl,[PageNumber]
and ecx,0xFF
mov ebp,[limits+ecx*4]
add ebp,0xFA0
cmp edi,ebp
je checkA
cmp byte[edi],0
je nextline
add edi,2
jmp checkA
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
je checkA
add edi,edx
checkA:
ret


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
jl checkAgain
sub edi,0xA0 ;80 * 2
cmp byte[edi-2],0
jne checkAgain
RepeatThat2:
mov eax,edi
mov cl,[PageNumber]
and ecx,0xFF
sub eax,[limits+ecx*4]
mov ecx,160
xor edx,edx
div ecx
cmp edx,0
je checkAgain
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
jge checkAgain
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
je checkAgain
sub edi,2
cmp byte[edi-2],0
je RepeatThat3
jmp checkAgain

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
jmp checkAgain
LMEA:
mov ebp,edi
HA2:
mov dx,[edi+2] ; char + color
mov [edi],dx
add edi,2
cmp dl,0
jne HA2
mov edi,ebp
jmp checkAgain

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
jmp checkAgain
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
sub edi , edx
add edi , 0x9E
iiiii:
cmp byte[edi-2], 0
jne ppppp
sub edi , 2
jmp iiiii
ppppp:
jmp checkAgain

je checkAgain
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
jmp checkAgain
;####### 0xE0




BKSP: 
cmp al,0x0E ; BKSP
jne TAB
test byte[STATUS],0x04 ; SHADED
jz ree
call DeleteFirst
jmp checkAgain
ree:

call backSpace

jmp checkAgain


TAB:
cmp al,0x0F ; tab ******
jne ENTR
mov ecx,8
LP_0:
push ecx
mov al,0x20 ; space
mov ah,0x0F
call Insert
pop ecx
loop LP_0
jmp checkAgain
ENTR:
cmp al,0x1C ; enter
jne NEXT2
entr:
push edi
mov al,[PageNumber]
and eax,0xFF
mov edi,[limits+eax*4]
add edi,0xE60 ; 24th line

LabelN:
push edi
mov edx,160 
 
cmp byte[edi],0
jne that2
add edi,edx
jmp enterAgain
that2:
mov esi,edi
add edi,edx
mov ecx,edx
LOO2:
push ecx
mov ax,[esi]
cmp al,0
je goThere2
mov byte[esi],0
call Insert
add esi,2
pop ecx
loop LOO2
sub esp,4
goThere2:
add esp,4
enterAgain:
pop edi
mov eax,edi
sub eax,[esp] ; fiiirst edi 
cmp eax,160
jl currentLine 
sub edi,160
jmp  LabelN
currentLine:
pop edi 
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
jmp checkAgain
that:
mov esi,edi
add edi,edx
push edi
mov ecx,edx
LOO:
push ecx
mov ax,[esi]
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
jmp checkAgain
NEXT2:
cmp AL,0x52
jne NEXT3
test byte[STATUS],0x01
jz checkAgain
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
jnz lef
call left
jmp checkAgain
lef:
mov AL,'4'
jmp print
NEXT7:
cmp al,0x4C
jne NEXT8
test byte[STATUS],0x01
jz checkAgain
mov AL,'5'
jmp print
NEXT8:
cmp al,0x4D
jne NEXT9
test byte[STATUS],0x01
jnz rig
call right
jmp checkAgain
rig:
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
jz checkAgain
mov al,'*'
jmp print
NEXT14:
cmp al,0x4A
jne NEXT15
test byte[STATUS],0x01
jz checkAgain
mov al,'-'
jmp print
NEXT15:
cmp al,0x4E
jne F_KEYS
test byte[STATUS],0x01
jz checkAgain
mov al,'+'
jmp print

F_KEYS:
cmp al,0x3B ; F1
jl CHARS
cmp al,0x42 ; F8
jg CHARS
sub al,0x3B ; get page index
call SetPage
jmp checkAgain
CHARS:

cmp al,0x80
jnb checkAgain
;;

JBR:
test byte[STATUS],0x08 ; check control status
jz SHI ; continue
;here when Control_Is_Pressed
cmp al,0x2E ; C
jne con2
test byte[STATUS],0x04 ; check shaded string
jz checkAgain
call COPY
jmp checkAgain
con2:
cmp al,0x2F ; V
jne con3
test byte[STATUS],0x04 ; check shaded string
jz jmpthere
call DeleteFirst
jmpthere:
call PASTE
jmp checkAgain

con3:
cmp al,0x2D ; X
jne con4
test byte[STATUS],0x04 ; check shaded string
jz checkAgain
call COPY
call DeleteFirst
jmp checkAgain

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
jmp checkAgain
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
mov ax,[PREVIOUS_STATUS + ecx*2] ; 
mov [esi+ecx*2],ax
inc ecx
cmp ecx,[length]
jl AD1_
LP_2:
sub edi,2
cmp byte[edi-2],0
je LP_2
jmp checkAgain
con6:
cmp al,0x1F ; S
jne checkAgain
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
mov ax,[esi+ecx*2]
mov [PREVIOUS_STATUS + ecx*2],ax
inc ecx
cmp ecx,[length]
jl AD_
pop edi
jmp checkAgain
;;
SHI:
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
push eax
call DeleteFirst
pop eax
mov [edi],al
add edi,2
jmp checkAgain
AMHB:
mov ah,0x0F ; white
call Insert

jmp checkAgain
DeleteFirst:
mov esi,[boundedBy]
mov edi,[boundedBy+4]
mov ecx,edi
sub ecx,esi
shr ecx,1
arj:
mov al,[esi]
cmp al,0
jne vcv
dec ecx
vcv:
mov eax,esi
mov dl,[PageNumber]
and edx,0xFF
sub eax,[limits+edx*4]
xor edx,edx
mov ebp, 160
div ebp
cmp edx,0
jne vvc
inc ecx
vvc:
add esi,2
cmp esi,edi
jl arj
OuterLp:
push ecx
call backSpace
pop ecx
loop OuterLp
and byte[STATUS],0xFB ; shaded
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
jmp checkAgain

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
jne checkAgain
AAG2:
in al,0x64
and al,0x01
jz AAG2
in al,0x60
LEFTSH:
cmp al,0x4B ; Left Arrow
jne RIGHTSH
test byte[STATUS],0x08
jz norm2

B_Loop:
call LSH
mov cl,[PageNumber]
and ecx,0xFF
cmp edi,[limits+ecx*4]
je checkAgain
mov cl,[PageNumber]
and ecx,0xFF
cmp edi,[limits+ecx*4]
je checkAgain
cmp byte[edi-2],0x20
je checkAgain
cmp byte[edi-2],','
je checkAgain
cmp byte[edi-2],';'
je checkAgain
cmp byte[edi-2],':'
je checkAgain
jmp B_Loop

norm2:
call LSH
jmp checkAgain

LSH:
mov cl,[PageNumber]
and ecx,0xFF
cmp edi,[limits+ecx*4]
je cdc
thisAgain:
sub edi,2
cmp byte[edi],0
je thisAgain

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
jmp cdc
VV:
or byte[STATUS],0x04 ; set
call SetColor
cdc:
ret


RIGHTSH:
cmp al,0x4D ; Right Arrow
jne UPSH
;cmp byte[edi],0
;je checkAgain
test byte[STATUS],0x08
jz norm3

A_Loop:
call RSH
cmp byte[edi],0x20
je checkAgain
cmp byte[edi],','
je checkAgain
cmp byte[edi],';'
je checkAgain
cmp byte[edi],':'
je checkAgain
cmp byte[edi],0
je checkAgain
jmp A_Loop

norm3:
call RSH
jmp checkAgain

RSH:
mov cl,[PageNumber]
and ecx,0xFF
mov ebp,[limits+ecx*4]
add ebp,0xFA0
cmp edi,ebp
je chec
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
ret
VVc:
or byte[STATUS],0x04 ; set
chec:
ret


UPSH:
cmp al,0x48 ; up
jne DOWNSH
mov ecx,80
plp2:
push ecx
cmp byte[edi-2],0
je eee2
call LSH
pop ecx
loop plp2
jmp checkAgain
eee2:
sub edi,2
pop ecx
loop plp2

agag2:
add edi,2
cmp byte[edi],0
je agag2

jmp checkAgain
DOWNSH:
cmp al,0x50 ;down
jne checkAgain
mov ecx,80
plp:
push ecx
cmp byte[edi],0
je eee
call RSH
pop ecx
loop plp
jmp checkAgain
eee:
add edi,2
pop ecx
loop plp

agag:

cmp byte[edi],0
jne checkAgain
sub edi,2
jmp agag

jmp checkAgain

PAGEDOWN:
mov al,[PageNumber]
cmp al,0
je checkAgain
dec al
call SetPage
jmp checkAgain
PAGEUP:
mov al,[PageNumber]
cmp al,7
je checkAgain
inc al
call SetPage
jmp checkAgain

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
mov [edi],ax
inc edi
inc edi
push edi
ther:
mov eax,edi
mov cl,[PageNumber]
and ecx,0xFF
sub eax,[limits+ecx*4]
mov ecx,160
xor edx,edx
div ecx
sub edx,160
sub edi,edx
cmp byte[edi],0
je rtrr
cmp byte[edi-2],0
je rtrr
cmp byte[edi],0x20
je rtrr
cmp byte[edi-2],0x20
je rtrr
asa:
sub edi,2
cmp byte[edi-2],0x20
jne asa
mov AL,' '
mov AH,0x0F
call Insert
jmp ther


rtrr:
pop edi
ret

backSpace:

mov cl,[PageNumber]
and ecx,0xFF
cmp edi,[limits+ecx*4]
jg d1
ret
 d1:
mov eax,edi
sub eax,[limits+ecx*4]
mov ecx,160
xor edx,edx
div ecx
cmp edx,0
je specialCase

mov ebp,edi
HH:
mov dx,[edi]
mov [edi-2],dx
add edi,2
cmp dl,0
jne HH
mov edi,ebp
sub edi,2
;;;;;
;;;;;
ret
specialCase:
mov cl,[PageNumber]
and ecx,0xFF
cmp edi,[limits+ecx*4]
je end1
mov ebp,edi
AHT:
mov dx,[edi]
mov [edi-2],dx
add edi,2
cmp dl,0
jne AHT
mov edi,ebp
sub edi,2
cmp byte[edi-2],0
jne end1


mov eax,edi
mov cl,[PageNumber]
and ecx,0xFF
sub eax,[limits+ecx*4]
mov ecx,160
xor edx,edx
div ecx
cmp edx,0
je end1
jmp specialCase
end1:
mov esi,edi
mov cl,[PageNumber]
and ecx,0xFF
mov ebp,[limits+ecx*4]
mov eax,esi
sub eax,ebp
mov ecx,160
xor edx,edx
div ecx
sub edx,160
sub esi,edx
add ebp,0xF00

Mst:
mov ax,[esi+160]
mov [esi],ax
add esi,2
cmp esi,ebp
jl Mst

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

COPY:

mov ecx,[boundedBy+4]
sub ecx,[boundedBy]; length
shr ecx,1 ; div by 2
mov [length],ecx
xor ecx,ecx
mov esi,[boundedBy]
AD:
mov ax,[esi+ecx*2]
and ah,0x0F ; remove shade
mov [MyMemory + ecx*2],ax
mov dl,[PageNumber]
and edx,0xFF
lea eax,[esi+ecx*2]
sub eax,[limits+edx*4]
mov ebp,0xA0
xor edx,edx
div ebp
cmp edx,0x9e
jne contm
mov al,0x13 ; newLine
mov ah,0x0F
inc ecx
sub esi,2
mov [MyMemory + ecx*2],ax
add dword[length],1
contm:
inc ecx
cmp ecx,[length]
jl AD


ret

PASTE:

xor ecx,ecx
AD2:

mov ax,[MyMemory + ecx*2]
cmp al,0
je vcx
cmp al,0x13 ; new line
jne dsd
push ecx
mov cl,[PageNumber]
and ecx,0xFF
mov eax,edi
sub eax,[limits+ecx*4]
xor edx,edx
mov ecx,160
div ecx
sub edx,160
neg edx
add edi,edx
pop ecx

jmp vcx
dsd:
push ecx
call Insert
pop ecx
vcx:

inc ecx
cmp ecx,[length]
jl AD2
ret
PageNumber: db 0
address: dd 0xB8000,0xB9000,0xBA000,0xBB000,0xBC000,0xBD000,0xBE000,0xBF000
limits: dd 0xB8000,0xB9000,0xBA000,0xBB000,0xBC000,0xBD000,0xBE000,0xBF000
enttr: db 0
ScanCodeTable:   db "//1234567890-=//qwertyuiop[]//asdfghjkl;'`/\zxcvbnm,.//// /"
ScanCodeTableSH: db '//!@#$%^&*()_+//QWERTYUIOP{}//ASDFGHJKL:"~/|ZXCVBNM<>?/// /' 
STATUS: db 0 ; X _ X _ X _ ALT _ CTRL _ SHADED _ CapsL _ NumL 
;  capslock at bit 1 and numlock at bit 0
;  bit 2 tells you if there is a shaded text (bounded between esi and edi)
; bit 3 for CTRL and bit 4 for ALT
length: dd 0
boundedBy: dd 0,0
MyMemory: times(25*80) dw 0
PREVIOUS_STATUS: times(25*80) dw 0
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
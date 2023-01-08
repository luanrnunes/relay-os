[BITS 16]
[ORG 0x7e00]

start:
    mov [DriveId],dl ; Carrega o DriveId presente no registrador dl que foi gravado no processo de boot
    mov eax,0x80000000
    cpuid
    cmp eax, 0x80000001 ; Se eax for menor que este valor, nao suporta long, pula para o erro
    jb NotSupport
    mov eax,0x80000001
    cpuid
    test edx, (1<<29)       ; Testa o edx para validar se suporta Long Mode
    jz NotSupport
    test edx, (1<<26)
    jz NotSupport

KernelStart:
    mov si,ReadPacket
    mov word [si],0x10 ; first word holds the value of structure length. ReadPacket is 16 (bytes) so it is 10 in hexa
    mov word [si+2],100 ; word 2 eh o numero de setores reservados, 100 (50kilobytes) e o suficiente para o kernel
    mov word [si+4],0; Offset mantem 0, como o endereco que quero apontar eh 10000, este valor ultrapassa WORD, no segmento multiplico 1000 por 16 e me da o valor 10000
    mov word [si+6],0x1000 ; Segmento aponta endereco 1000 linha acima detalha
    mov dword [si+8],6 ; 6(7 bits=0-6) reservados no registrador baixo de 64bits
    mov dword [si+0xc], 0 ; Na alta 64 bits, e reservado apenas 1
    mov dl,[DriveId]
    mov ah,0x42
    int 0x13
    jc ReadError ; Se nao conseguir ler setores, pula para o erro

    
MemStatsInit:
    mov eax,0xe820
    mov edx,0x534d4150
    mov ecx,20
    mov edi,0x9000
    xor ebx,ebx
    int 0x15 ; Se carry flag para a primeira call da funcao, o servico e820 nao e suportado
    jc NotSupport

MemStatsGet:
    add edi,20 ; Aponto o edi para receber o proximo bloco de memoria (cada bloco de memoria e 20)
    mov eax,0xe820
    mov edx,0x534d4150
    mov ecx,20
    int 0x15
    jc EndMem ; Se carry flag, significa que cheguei ao fim do bloco de memoria. Faco call a EndMem
    test ebx,ebx ; Se nao carry flag, testa o ebx
    jnz MemStatsGet; Jump para o inicio if zero flag is not set

EndMem:
 

A20:
    mov ax,0xffff
    mov es,ax
    mov word[ds:0x7c00],0xa200 ; Instrucao vai copiar a200 na memoria em 7c00
    cmp word[es:0x7c10],0xa200
    jne A20End
    mov word[0x7c00],0xb200
    cmp word[es:0x7c10],0xb200 ; Compara os valores, se permanecer o mesmo, significa que a20 esta desbilitado
    je End; Jump if Equal

A20End:
    xor ax,ax
    mov es,ax

Video:
    mov ax,3 ; Seta o modo de video para texto
    int 0x10
    cli
    lgdt [Gdt32Ptr]
    lidt [Idt32Ptr]
    mov eax,cr0
    or eax,1 ; Altera o bit de 0 para 1
    mov cr0,eax ; Passando o valor novamente para o cr0
    jmp 8:Protected ; Nao e possivel utilizar mov para registrador cs. Aqui entra em Protected Mode
    
ReadError:
NotSupport:
End:
    hlt
    jmp End

[BITS 32]
Protected:          ; Este bloco basicamente encontra area de memoria livre e inicializa a estrutura de paginacao
    mov ax,0x10
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov esp,0x7c00
    cld             
    mov edi,0x80000
    xor eax,eax
    mov ecx,0x10000/4
    rep stosd
    mov dword [0x80000],0x81007
    mov dword [0x81000],10000111b
    mov eax,cr4 ; Mover o conteudo de cr4 para eax. Inicializando modo 64bits
    or eax,(1<<5) ; Setando bit 5
    mov cr4,eax ; E devolvendo o bit modificado para o cr4
    mov eax,0x80000
    mov cr3,eax ; O endereco carregado para cr3 e fisico
    mov ecx,0xc0000080
    rdmsr ; Read MSR
    or eax, (1<<8)  ; O valor do retorno esta no registrador eax, entao defini 8 bits
    wrmsr      ; Entao escrevo novamente no registro
    mov eax,cr0
    or eax,(1<<31)
    mov cr0,eax
    jmp 8:LongMode

ProtectedHalt:
    hlt
    jmp ProtectedHalt


[BITS 64]
LongMode:
    mov rsp,0x7c00
    mov byte[0xb8000],'L'
    mov byte[0xb8001],0xa

LongModeHalt:
    hlt
    jmp LongModeHalt

DriveId: db 0
ReadPacket: times 16 db 0

Gdt32:
    dq 0 ; Alocados 8 bytes com dq para inicializar o gdt

x86:
    dw 0xffff ; Segmento definido ao valor maximo
    dw 0
    db 0 ; Segmento inicia do zero
    db 0x9a
    db 0xcf
    db 0

Datax86:
    dw 0xffff ; Segmento definido ao valor maximo
    dw 0
    db 0 ; Segmento inicia do zero
    db 0x92
    db 0xcf
    db 0

Gdt32Len: equ $-Gdt32
                                    ; Data Pointers
Gdt32Ptr: dw Gdt32Len-1
          dd Gdt32 ; Os proximos 4 bytes sao o endereco do gdt

Idt32Ptr: dw 0
          dd 0

Gdt64:
    dq 0 ; Inicializado Gdt64
    dq 0x0020980000000000

Gdt64Len: equ $-Gdt64

Gdt64ptr: dw Gdt64Len-1; Os primeiros dois bytes define o tamanho do gdt
          dw Gdt64 ; Proximos 4 bytes e o endereco do gdt
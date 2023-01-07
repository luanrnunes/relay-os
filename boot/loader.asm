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
    mov ah,0x13
    mov al,1
    mov bx,0xa
    xor dx,dx
    mov bp,Message
    mov cx,MessageLen 
    int 0x10

ReadError:
NotSupport:
End:
    hlt
    jmp End
DriveId: db 0
Message: db "KERNEL LOADED SUCCESSFULLY!"
MessageLen: equ $-Message
ReadPacket: times 16 db 0
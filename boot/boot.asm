[BITS 16]
[ORG 0x7c00]

start:
    xor ax,ax   
    mov ds,ax
    mov es,ax  
    mov ss,ax
    mov sp,0x7c00

TestDiskExtension:
    mov [DriveId],dl
    mov ah,0x41
    mov bx,0x55aa
    int 0x13
    jc NotSupport
    cmp bx,0xaa55 ; Se bx nao for igual a AA55 significa que nao suporta a extensao
    jne NotSupport

Loader:
    mov si,ReadPacket
    mov word [si],0x10 ; first word holds the value of structure length. ReadPacket is 16 (bytes) so it is 10 in hexa
    mov word [si+2],5 ; word 2 e o numero de setores reservados, 5 ja basta pois o loader e pequeno
    mov word [si+4],0x7e00 ; Inicia a leitura de word no endereco 0x7e00
    mov word [si+6],0 ; Segmento da execucao, nao ha mudancas, defino em 0
    mov dword [si+8],1 ; 1(2 bits=0-1) reservados no registrador baixo de 64bits
    mov dword [si+0xc], 0 ; Na alta 64 bits, e reservado apenas 1
    mov dl,[DriveId]
    mov ah,0x42
    int 0x13
    jc ReadError ; Se nao conseguir ler setores, pula para o erro
    mov dl,[DriveId] ; Se o loader for alocado com sucesso na memoria, passa o valor de DriveId para o registrador dl
    jmp 0x7e00 ; Pula para o endereco de memoria onde esta o loader carregado do disco
ReadError:
NotSupport:
    mov ah,0x13
    mov al,1
    mov bx,0xa
    xor dx,dx
    mov bp,Message
    mov cx,MessageLen 
    int 0x10

End:
    hlt    
    jmp End
     
DriveId: db 0
Message:    db "FATAL ERROR DURING BOOT PROCESS!"
MessageLen: equ $-Message ; Lembrar que $ ajusta o tamanho da mensagem de acordo
ReadPacket: times 16 db 0

times (0x1be-($-$$)) db 0

    db 80h
    db 0,2,0
    db 0f0h
    db 0ffh,0ffh,0ffh
    dd 1
    dd (20*16*63-1)
	
    times (16*3) db 0

    db 0x55
    db 0xaa

	

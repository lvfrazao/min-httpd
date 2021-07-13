bits 64
default rel
global itoa

; uint64_t itoa(uint64_t number, char *str_buffer, uint64_t str_buffer_len)
; rdi: number
; rsi: str_buffer
; rdx: str_buffer_len
; Return number of bytes written to buffer in rax
; Clobbers rcx, rdx, rax, r8
itoa:
    push rbp
    mov rbp, rsp

    ; Check if the str_buffer_len is at least 1 byte long
    cmp rdx, 0
    je .error

    dec rdx ; We need to reserve one byte for the null byte
    mov r8, rdx ; copy rdx to r8

    mov rax, rdi ; Copy number to rax where we will be doing division
    mov rcx, 10

    ; Null terminated string
    dec rsp
    mov byte [rsp], 0

    test rax, rax
    jne .itoa_loop
    dec rsp
    mov byte [rsp], 48 ; If the sum is 0 we need to push a 0 char
.itoa_loop:
    cmp rax, 0
    je .write_loop
    xor rdx, rdx
    div rcx ; Divide by ten, remainder gets put into RDX
    add rdx, 48

    ; Save current character on the stack and loop back
    dec rsp
    mov [rsp], dl
    jmp .itoa_loop

.write_loop:
    ; Check if we've hit the null byte
    cmp byte [rsp], 0
    je .done
    ; Check if we're going to overrun our buffer
    cmp rax, r8
    je .error

    ; Move next byte into cl from the stack
    mov cl, byte [rsp]
    inc rsp
    ; Save the character in our string buffer
    mov byte [rsi + rax], cl
    inc rax
    jmp .write_loop

.done:
    mov byte [rsi + rax], 0
    leave
    ret
.error:
    xor rax, rax
    leave
    ret

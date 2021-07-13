bits 64
default rel
global _start

; syscalls
SYS_CLOSE: equ 3
SYS_SOCKET: equ 41
SYS_ACCEPT: equ 43
SYS_SENDTO: equ 44
SYS_RECVFROM: equ 45
SYS_BIND: equ 49
SYS_LISTEN: equ 50
SYS_FORK: equ 57
SYS_EXIT: equ 60
; socket constants
AF_INET: equ 2
SOCK_STREAM: equ 1
; other constants
LISTEN_BACKLOG: equ 128
RECV_BUFFER_SIZE: equ 1024

section .data
; struct sockaddr __user
align 8
sockaddr:
    sin_family dw AF_INET
    sin_port dw 5000h ; 80 in little endian, gets stored as LE (which makes it 80 in BE)
    sin_addr dd 0
    sin_zero dq 0
addr_len: dd 16

section .bss
recv_buffer: resb RECV_BUFFER_SIZE ; Max request is 1024 bytes

section .text
_start:
httpd:
    push rbp
    mov rbp, rsp
    ; A simple HTTP server
    ; IPv4 only
    ; Takes a single argument: port to listen on
    ; Serves from the current working directory
    ; Only accepts GET requests

; Create a socket by calling the `socket` syscall
; No parameters to this section, it will always make an AF_INET, SOCK_STREAM type socket
; Clobbers rcx, r11, rax, rdi, rsi
.create_socket:
    ; socket(AF_INET, SOCK_STREAM, IPPROTO_IP) = 3
    mov rax, SYS_SOCKET;
    mov rdi, AF_INET
    mov rsi, SOCK_STREAM
    xor rdx, rdx
    syscall
    ; TODO: Error check socket syscall

    ; Save our socket FD in r12
    mov r12, rax

; Bind our socket to "0.0.0.0:80"
.bind_addr:
    ; bind(3, {sa_family=AF_INET, sin_port=htons(80), sin_addr=inet_addr("0.0.0.0")}, 16) = 0
    mov rax, SYS_BIND
    mov rdi, r12
    lea rsi, [sockaddr] ; our struct sockaddr __user *
    mov rdx, 16
    syscall
    ; TODO: Error check bind syscall
    test rax, rax
    jnz .exit_failure

.listen:
    ; listen(3, 128)                          = 0
    mov rax, SYS_LISTEN
    mov rdi, r12
    mov rsi, LISTEN_BACKLOG
    syscall
    ; TODO: Error check listen syscall
    test rax, rax
    jnz .exit_failure

; loop on blocking accept
.serve_forever:
    ; accept(3, {sa_family=AF_INET, sin_port=htons(47464), sin_addr=inet_addr("127.0.0.1")}, [16]) = 4
    mov rax, SYS_ACCEPT
    mov rdi, r12
    lea rcx, [sockaddr]
    mov rsi, rcx ; our struct sockaddr * for the client
    lea rdx, [addr_len] ; Data structure len
    syscall
    ; TODO: Error check accept syscall
    ; Log failure instead of crashing
    ; TODO: info level logging on clients connecting
    cmp rax, 0
    jl .exit_failure

    ; Save the client FD in r13
    mov r13, rax

    ; fork then call recv on the child, unconditional jump to accept on parent
.fork:
    ; fork();
    mov rax, SYS_FORK
    syscall

    ; TODO: Error check fork syscall
    ; Log failure instead of crashing
    cmp rax, 0
    setne r14b ; r14 is nonzero if were in the parent
    jl .exit_failure
    jnz .close_conn ; Parent process must close the client FD, and loop back

    call recv ; child proc must receive the msg and respond to it
    call respond

.close_conn:
    ; Close the client fd
    ; close(4)                                = 0
    mov rax, SYS_CLOSE
    mov rdi, r13
    syscall

    cmp r14, 0 ; r14 is 0 in the child proc, non-zero in the parent proc
    ja .serve_forever ; Parent process must close the client FD, and loop back

.exit_success:
    xor rdi, rdi
    jmp .exit
.exit_failure:
    mov rdi, 1
.exit:
    mov rax, SYS_EXIT
    syscall

; Clobbers: rcv, r11, rax, rdi, rsi, rdx, r10, r8, r9
recv:
    ; recvfrom(4, "hello\n", 1024, 0, NULL, NULL) = 6
    mov rax, SYS_RECVFROM
    mov rdi, r13                ; Socket FD to read from
    lea rsi, [recv_buffer]      ; buffer for msg
    mov rdx, RECV_BUFFER_SIZE   ; buffer size
    mov r10, 0                  ; flags
    mov r8, 0                   ; src_addr struct
    mov r9, 0                   ; src_addr struct size
    syscall

    mov r15, rax ; Save the received message size
    
    ret

; Clobbers: rcv, r11, rax, rdi, rsi, rdx, r10, r8, r9
respond:
    ; Do response
    ; sendto(4, "hello\n", 6, 0, NULL, 0)     = 6
    mov rax, SYS_SENDTO
    mov rdi, r13                ; Socket FD to send to
    lea rsi, [recv_buffer]      ; buffer for msg
    mov rdx, r15                ; Message size
    mov r10, 0                  ; flags
    mov r8, 0                   ; src_addr struct
    mov r9, 0                   ; src_addr struct size
    syscall
    ret

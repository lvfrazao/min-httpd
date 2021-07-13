bits 64
default rel
global httpd
extern log_debug, log_info, log_warn, log_error, log_critical, itoa

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

section .rodata
log_msg_socket: db "Created TCP socket"
log_msg_socket_len: equ $-log_msg_socket
log_msg_bind: db "Bound socket to port"
log_msg_bind_len: equ $-log_msg_bind
log_msg_listen: db "Server listening on bound port"
log_msg_listen_len: equ $-log_msg_listen

section .data
; struct sockaddr __user
struc sockaddr
    .sin_family: resw 1
    .sin_port: resw 1
    .sin_addr: resd 1
    .sin_zero: resq 1
endstruc
align 8
addr:
    istruc sockaddr
        at sockaddr.sin_family, dw AF_INET
        at sockaddr.sin_port, dw 5000h ; Gets stored as little endian (which makes it 80 in BE)
        at sockaddr.sin_addr, dd 0
        at sockaddr.sin_zero, dq 0
    iend
addr_len: dd 16

log_msg_accept: db "Client connected: ?.?.?.?:?            " ; Enough space leftover to log IP and port
log_msg_accept_len: equ $-log_msg_accept
log_msg_accept_ip_idx: equ 18 ; Where to start writting the IP and port

section .bss
recv_buffer: resb RECV_BUFFER_SIZE ; Max request is 1024 bytes

section .text
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

%ifdef DEBUG
    ; Log sock creation
    lea rdi, [log_msg_socket]
    mov rsi, log_msg_socket_len
    call log_debug
%endif

; Bind our socket to "0.0.0.0:80"
.bind_addr:
    ; bind(3, {sa_family=AF_INET, sin_port=htons(80), sin_addr=inet_addr("0.0.0.0")}, 16) = 0
    mov rax, SYS_BIND
    mov rdi, r12
    lea rsi, [addr] ; our struct sockaddr __user *
    mov rdx, 16
    syscall
    ; TODO: Error check bind syscall
    test rax, rax
    jnz .exit_failure

%ifdef DEBUG
    ; Log bind
    lea rdi, [log_msg_bind]
    mov rsi, log_msg_bind_len
    call log_debug
%endif

.listen:
    ; listen(3, 128)                          = 0
    mov rax, SYS_LISTEN
    mov rdi, r12
    mov rsi, LISTEN_BACKLOG
    syscall
    ; TODO: Error check listen syscall
    test rax, rax
    jnz .exit_failure

    ; Log listen
    lea rdi, [log_msg_listen]
    mov rsi, log_msg_listen_len
    call log_info

; loop on blocking accept
.serve_forever:
    ; accept(3, {sa_family=AF_INET, sin_port=htons(47464), sin_addr=inet_addr("127.0.0.1")}, [16]) = 4
    mov rax, SYS_ACCEPT
    mov rdi, r12
    lea rcx, [addr]
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

%ifdef LOG_IPS
    ; Log the accepted connection
    ; 1st octet of IP
    mov r9, rsi
    movzx rdi, byte [r9 + sockaddr.sin_addr + 0] ; The number to convert to ascii
    lea rsi, [log_msg_accept + log_msg_accept_ip_idx]
    mov rdx, log_msg_accept_len
    sub rdx, log_msg_accept_ip_idx ; Space left in buffer

    push rdx
    call itoa
    pop rdx

    add rsi, rax    ; Add to the pointer value the num chars written
    sub rdx, rax    ; Subtract the num bytes written from remaining
    mov byte [rsi], "."
    inc rsi
    dec rdx

    ; Second Octet
    movzx rdi, byte [r9 + sockaddr.sin_addr + 1] ; The number to convert to ascii
    push rdx
    call itoa
    pop rdx

    add rsi, rax    ; Add to the pointer value the num chars written
    sub rdx, rax    ; Subtract the num bytes written from remaining
    mov byte [rsi], "."
    inc rsi
    dec rdx

    ; Third Octet
    movzx rdi, byte [r9 + sockaddr.sin_addr + 2] ; The number to convert to ascii
    push rdx
    call itoa
    pop rdx

    add rsi, rax    ; Add to the pointer value the num chars written
    sub rdx, rax    ; Subtract the num bytes written from remaining
    mov byte [rsi], "."
    inc rsi
    dec rdx

    ; Fourth Octet
    movzx rdi, byte [r9 + sockaddr.sin_addr + 3] ; The number to convert to ascii
    push rdx
    call itoa
    pop rdx

    add rsi, rax    ; Add to the pointer value the num chars written
    sub rdx, rax    ; Subtract the num bytes written from remaining
    mov byte [rsi], ":"
    inc rsi
    dec rdx

    ; Port
    ; Need to swap endianess
    movzx rdi, byte [r9 + sockaddr.sin_port] ; The number to convert to ascii
    shl rdi, 8
    mov dil, byte [r9 + sockaddr.sin_port + 1]
    push rdx
    call itoa
    pop rdx
%endif

    ; Log accept
    lea rdi, [log_msg_accept]
    mov rsi, log_msg_accept_len
    call log_info

    ; fork the proc for each request
    ; Child: call recv and respond
    ; Parent: close FD + unconditional jump to accept
.fork:
    ; rax = fork();
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

; recv
; Receives the message from the client and copies it into recv_buffer
; Reads from the socket FD stored in r13
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

; path_from_request
; Given an HTTP request stored in recv_buffer, path_from_request parses the
; request and returns the path to the file being requested.
; This path is stored as a null terminated string in recv_buffer. The string
; len is returned in rax.
path_from_request:
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

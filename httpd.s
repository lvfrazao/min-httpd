bits 64
default rel
global httpd
extern log_debug, log_info, log_warn, log_error, log_critical, itoa, write_to_buf

; syscalls
SYS_READ: equ 0
SYS_OPEN: equ 2
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
O_RDONLY: equ 0     ; File reading flag
CREATE_MODE: equ 0  ; File open mode param

section .rodata
log_msg_socket: db "Created TCP socket"
log_msg_socket_len: equ $-log_msg_socket
log_msg_bind: db "Bound socket to port"
log_msg_bind_len: equ $-log_msg_bind
log_msg_listen: db "Server listening on bound port"
log_msg_listen_len: equ $-log_msg_listen

method_get: db "GET "

; "Special" files
file_not_found: db "/404.html",0
file_not_found_len: equ $-file_not_found
file_method_not_allowed: db "/405.html",0
file_method_not_allowed_len: equ $-file_method_not_allowed
file_internal_server_error: db "/500.html",0
file_internal_server_error_len: equ $-file_internal_server_error

; Status lines
status_ok: db "HTTP/1.0 200",13,10
status_ok_len: equ $-status_ok
status_not_found: db "HTTP/1.0 404",13,10
status_not_found_len: equ $-status_not_found
status_method_not_allowed: db "HTTP/1.0 405",13,10
status_method_not_allowed_len: equ $-status_method_not_allowed
status_internal_server_error: db "HTTP/1.0 500",13,10
status_internal_server_error_len: equ $-status_internal_server_error
double_crlf: db 13,10,13,10

; Content-type headers
content_type_html: db "Content-Type: text/html",13,10
content_type_html_len: equ $-content_type_html

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

; Root of all files to be served
server_root: db "./index"
server_root_len: equ $-server_root
server_root_file: db "index.html"
server_root_file_len: equ $-server_root_file
root_request: db "/",0
root_file: db "/index.html"
root_file_len: equ $-root_file

section .bss
recv_buffer: resb RECV_BUFFER_SIZE ; Max request is 1024 bytes
filename: resb RECV_BUFFER_SIZE ; Name of file to serve
http_status: resq 1 ; Pointer to status msg to be used
http_status_len: resq 1 ; Scalar value
content_type: resb RECV_BUFFER_SIZE
content_type_len: resq 1

section .text
httpd:
    push rbp
    mov rbp, rsp
    ; A simple HTTP server
    ; IPv4 only
    ; Takes two arguments
    ; 1) Port to listen on
    ; 2) Base directory to read from
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
    call path_from_request

    lea rdi, [filename] ; File to respond with
    call load_file_to_buf

    mov rdi, rax
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
    ; Check method, if not get return 405
    ; if (method != "GET") {
    ;     status = 405;
    ;     file = "405.html";
    ; }
    lea rax, [recv_buffer]
    mov eax, dword [rax]
    lea rcx, [method_get]
    cmp eax, dword [rcx]
    jne .method_not_allowed

    lea rax, [recv_buffer]
    add rax, 4 ; Skip "GET "
    xor rcx, rcx
.loop:
    ; Check if finished
    cmp byte [rax + rcx], " "
    je .done_loop ; Finish parsing at first space, yes, I know, this isnt kosher, filenames can have spaces.
    ; Check for bounds
    cmp rcx, RECV_BUFFER_SIZE - 4
    je .done_loop

    inc rcx
    jmp .loop
.done_loop:
    cmp rcx, 1
    jne .load_filename

    ; If equal it means that theyre requesting the root "/"
    ; We must load "index.html"
    lea rax, [root_file]
    mov rcx, root_file_len

.load_filename:
    push rcx    ; Str size
    push rax    ; Str pointer
    ; use write_to_buf to fill in filename
    lea rdi, [filename]                 ; destination buffer
    xor rsi, rsi                        ; index to start copying at
    mov rdx, RECV_BUFFER_SIZE           ; dest buffer size
    lea rcx, [server_root]              ; src buffer
    mov r8, server_root_len             ; src buffer size
    call write_to_buf

    ; rsi is set from the previous write_to_buf call
    ; Can keep rdi set from previous call
    mov rdx, RECV_BUFFER_SIZE           ; dest buffer size
    pop rcx ; Filename pointer
    pop r8 ; Filename size
    call write_to_buf

    mov rax, r8 ; Return the filename len
    add rax, server_root_len

    mov byte [rdi + rsi], 0             ; Null terminate the string
    inc rax

    ; Set status
    lea rdi, [status_ok]
    lea rsi, [http_status]
    mov [rsi], rdi
    lea rsi, [http_status_len]
    mov qword [rsi], status_ok_len

    ; Set content type
    ; TODO: recognize types other than text/html
    lea rdi, [content_type_html]
    lea rsi, [content_type]
    mov [rsi], rdi
    lea rsi, [content_type_len]
    mov qword [rsi], content_type_html_len

    ret
.method_not_allowed:
    ; use write_to_buf to fill in filename
    lea rdi, [filename]                 ; destination buffer
    xor rsi, rsi                        ; index to start copying at
    mov rdx, RECV_BUFFER_SIZE           ; dest buffer size
    lea rcx, [server_root]              ; src buffer
    mov r8, server_root_len             ; src buffer size
    call write_to_buf
    mov rax, r8 ; Return the filename len

    ; rsi is set from the previous write_to_buf call
    ; Can keep rdi set from previous call
    mov rdx, RECV_BUFFER_SIZE           ; dest buffer size
    lea rcx, [file_method_not_allowed]
    mov r8, file_method_not_allowed_len
    push rax
    call write_to_buf
    mov byte [rdi + rsi], 0             ; Null terminate the string
    pop rax
    add rax, r8


    ; Set status
    lea rdi, [status_method_not_allowed]
    lea rsi, [http_status]
    mov [rsi], rdi
    lea rsi, [http_status_len]
    mov qword [rsi], status_method_not_allowed_len

    ret

; uint64_t load_file_to_buf(char *filename)
; rdi: filename
; Returns number of bytes read in rax
; Clobbers: rcx, r11
load_file_to_buf:
    ; Open the file and read it into the reponse buffer
    mov rax, SYS_OPEN
    ; rdi already contains the filename
    mov rsi, O_RDONLY
    mov rdx, CREATE_MODE
    syscall

    ; FD in rax now
    cmp rax, 0
    jge .copy_to_resp_buf ; Positive numbers means success
.error:
    ; Issue a not found response

    ; use write_to_buf to fill in filename
    lea rdi, [filename]                 ; destination buffer
    xor rsi, rsi                        ; index to start copying at
    mov rdx, RECV_BUFFER_SIZE           ; dest buffer size
    lea rcx, [server_root]              ; src buffer
    mov r8, server_root_len             ; src buffer size
    call write_to_buf
    mov rax, r8 ; Return the filename len

    ; rsi is set from the previous write_to_buf call
    ; Can keep rdi set from previous call
    mov rdx, RECV_BUFFER_SIZE           ; dest buffer size
    lea rcx, [file_not_found]
    mov r8, file_not_found_len
    push rax
    call write_to_buf
    mov byte [rdi + rsi], 0             ; Null terminate the string
    pop rax
    add rax, r8

    ; TODO: Cache the whole file in memory

    ; Set the status
    lea rdi, [status_not_found]
    lea rsi, [http_status]
    lea rdx, [http_status_len]
    mov rcx, status_not_found_len
    call set_status

    ; Recurse to the load_file_to_buf function
    ; Dangerous? If index/404.html is missing this could peg a CPU.
    lea rdi, [filename]
    jmp load_file_to_buf

.copy_to_resp_buf:
    push rax ; Save the FD for a second

    lea rdi, [recv_buffer]
    xor rsi, rsi
    mov rdx, RECV_BUFFER_SIZE
    lea rcx, [http_status]
    mov rcx, [rcx] ; pointer to http_status
    lea r8, [http_status_len] ; src buf
    mov r8, qword [r8] ; src buf size
    call write_to_buf

    ; Our status code is now in our response buffer
    ; Add our content-type header now
    lea rcx, [content_type]
    mov rcx, [rcx] ; pointer to content type
    lea r8, [content_type_len] ; src buf
    mov r8, qword [r8] ; src buf size
    call write_to_buf

    ; Add an additional cr/lf to the end of the headers section
    lea rcx, [double_crlf]
    mov cx, word [rcx]
    mov word [rdi + rsi], cx
    add rsi, 2

    mov rdx, RECV_BUFFER_SIZE ; Max size
    sub rdx, rsi ; Adjust for the status line len
    ; rsi points to the response buffer, starting after the headers
    lea rsi, [rdi + rsi]
    mov rax, SYS_READ
    pop rdi ; Pop the FD into rdi
    syscall

    ; As always, finish our response with two CRLF
    add rsi, rax ; Add the read bytes
    lea rdi, [double_crlf]
    mov edi, dword [rdi]
    mov dword [rsi], edi
    add rsi, 4

    ; Calculate total len of msg
    lea rax, [recv_buffer]
    sub rsi, rax
    mov rax, rsi

    ret

; set_status(char *status_msg, char **status_ptr, uint64_t *status_len_storage, uint64_t *status_len_ptr, uint64_t status_len)
; Sets the status double pointer to the status msg we want
; rdi: Char pointer to status msg we want
; rsi: Double char pointer to status msg buffer
; rdx: unint64_t pointer to status msg len
; rcx: unint64_t status msg len
add_header:
set_status:
    mov [rsi], rdi          ; Put pointer to our status msg in the status double pointer
    mov qword [rdx], rcx    ; Put the len of our status msg in the msg len ptr
    ret

; uint64_t respond(uint64_t msg_len)
respond:
    ; Do response
    ; sendto(4, "hello\n", 6, 0, NULL, 0)     = 6
    mov rax, SYS_SENDTO
    lea rsi, [recv_buffer]      ; buffer for msg
    mov rdx, rdi                ; Message size
    mov rdi, r13                ; Socket FD to send to
    mov r10, 0                  ; flags
    mov r8, 0                   ; src_addr struct
    mov r9, 0                   ; src_addr struct size
    syscall
    ret

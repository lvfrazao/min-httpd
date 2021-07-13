bits 64
default rel
extern itoa
global get_epoch_time, log_info, write_to_buf

; syscalls
SYS_WRITE: equ 1
SYS_GETTIMEOFDAY: equ 96
; Other constants
STDERR: equ 2

section .rodata
; log levels:
log_level_debug: db "DEBUG: "
log_level_debug_len: equ $-log_level_debug

log_level_info: db "INFO: "
log_level_info_len: equ $-log_level_info

log_level_warn: db "WARN: "
log_level_warn_len: equ $-log_level_warn

log_level_error: db "ERROR: "
log_level_error_len: equ $-log_level_error

log_level_critical: db "CRITICAL: "
log_level_critical_len: equ $-log_level_critical

section .data


section .bss
LOG_MSG_MAX_SIZE: equ 1024 ; arbitrary limit on log msg size
align 16
log_msg: resb LOG_MSG_MAX_SIZE
struc timeval
    .tv_sec  resq 1
    .tv_nsec resq 1
endstruc
current_epoch: resb timeval_size

section .text

; Writes the text stored in a string buffer to standard error
; Params:
; msg length: rdi
; msg buffer: rsi
; Returns number of bytes written in rax
; Clobbers: rcx, r11, rdi, rsi, rdx
write_to_stderr:
    mov rdx, rdi ; Put the msg len in the right register
    mov rax, SYS_WRITE
    mov rdi, STDERR
    syscall
    ret

; uint64_t write_to_buf(char *dst_buffer, uint64_t dst_buffer_index,
;                       uint64_t dst_buffer_size, char *src_buffer,
;                       uint64_t src_buffer_size)
; Does not null terminate (unless the src string is null terminated)
; This is basically memcpy
; rdi: dest buffer
; rsi: dest index
; rdx: dest buffer size
; rcx: src buffer
; r8:  src size
; Returns number of bytes written in rax
; Clobbers rdi, rsi, rdx, rcx, r8
write_to_buf:
    ; Do a bounds check - check if copy will overrun buffer
    xor rax, rax
    mov r9, r8
    add r9, rsi
    cmp r9, rdx
    ja .error
.write_loop:
    cmp rsi, r9
    je .done
    mov dl, byte [rcx + rax]
    mov byte [rdi + rsi], dl
    inc rsi
    inc rax
    jmp .write_loop
.done:
    ret
.error:
    ; Do something different on error?
    ret


; uint64_t get_epoch_time(str_buffer);
; Get epoch time and write it to the buffer provided in rdi
; Param 1: string buffer -> rdi
; Returns the number of bytes written
; clobbers rax, rdi, rsi, rcx, r11
get_epoch_time:
    mov rax, SYS_GETTIMEOFDAY
    lea rdi, [current_epoch]
    xor rsi, rsi
    syscall

    ; TODO: error handle a failed call to gettimeofday

    ; Call itoa on the current_epoch->tv_sec
    ; uint64_t itoa(uint64_t number, char *str_buffer, uint64_t str_buffer_len)
    lea rdi, [current_epoch + timeval.tv_sec]
    mov rdi, [rdi]
    lea rsi, [log_msg]
    mov rdx, LOG_MSG_MAX_SIZE ; time must always the first thing written to the buffer
    call itoa ; number of bytes written returned in rax
    ret

log_info:
    call get_epoch_time
    mov rdi, rax
    lea rsi, [log_msg]
    call write_to_stderr
    ret

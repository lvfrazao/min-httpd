bits 64
default rel
extern itoa

; syscalls
SYS_WRITE: equ 1
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
SLEEP_TIME:
    tv_sec  dq 0
    tv_nsec dq 0

section .bss
LOG_MSG_MAX_SIZE: equ 1024 ; arbitrary limit on log msg size
log_msg: resb LOG_MSG_MAX_SIZE

section .text

; Writes the text stored in log_msg to standard error
; Params:
; msg length: rdx
; Returns number of bytes written in rax
; Clobbers: rcx, r11, rdi, rsi
write_to_stderr:
    mov rax, SYS_WRITE
    mov rdi, STDERR
    lea rsi, [log_msg]
    syscall
    ret

log_info:
    
    ret

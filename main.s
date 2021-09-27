bits 64
default rel
global _start
extern serve_forever

section .text
_start:
    jmp serve_forever

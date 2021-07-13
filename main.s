bits 64
default rel
global _start
extern httpd

section .text
_start:
    call httpd

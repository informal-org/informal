section .text
    global _start

_start:
    mov rdx, msglen
    mov rsi, msg
    mov rax, 1      ;; arg0 - file-handle (1=stdout)
    mov rdi, 1      ;; syscall 4 = write
    syscall        ;; kernel-call. int 0x80 = syscall
    mov rax, 60      ;; exit(0).
    mov rdi, 0      ;; syscall-1 = exit.
    syscall

section .rodata
    msg: db 'Hello, World!', 10
    msglen: equ $ - msg         ; length of msg string.

%ifndef SOURCE_READER_ASM
%define SOURCE_READER_ASM

%define SOURCE_CAPACITY 1048576
%define SOURCE_EOF      256

; PROCESS_SOURCE filename_label, handler_label
%macro PROCESS_SOURCE 2
    lea rdi, [rel %1]
    lea rsi, [rel %2]
    call source_for_each
%endmacro

section .bss
    source_buffer:   resb SOURCE_CAPACITY + 1
    source_length:   resq 1
    source_position: resq 1
    source_fd:       resq 1
    source_callback: resq 1

section .text

; rdi = filename
; returns:
;   rax = 0 on success
;   rax < 0 on error
source_load:
    mov eax, 2
    xor esi, esi
    xor edx, edx
    syscall

    test rax, rax
    js .return

    mov [rel source_fd], rax
    xor r8d, r8d

.read_more:
    cmp r8, SOURCE_CAPACITY + 1
    jae .too_large

    xor eax, eax
    mov rdi, [rel source_fd]

    lea rsi, [rel source_buffer]
    add rsi, r8

    mov edx, SOURCE_CAPACITY + 1
    sub rdx, r8
    syscall

    test rax, rax
    js .read_error

    test rax, rax
    jz .loaded

    add r8, rax
    jmp .read_more

.loaded:
    cmp r8, SOURCE_CAPACITY
    ja .too_large

    mov [rel source_length], r8
    mov qword [rel source_position], 0

    mov eax, 3
    mov rdi, [rel source_fd]
    syscall

    xor eax, eax
    ret

.read_error:
    mov r9, rax

    mov eax, 3
    mov rdi, [rel source_fd]
    syscall

    mov rax, r9
    ret

.too_large:
    mov eax, 3
    mov rdi, [rel source_fd]
    syscall

    mov rax, -27
    ret

.return:
    ret

; Returns:
;   rax = 0..255 for a character
;   rax = SOURCE_EOF at the end
source_next:
    mov rdx, [rel source_position]
    cmp rdx, [rel source_length]
    jae .end

    lea rcx, [rel source_buffer]
    movzx eax, byte [rcx + rdx]

    inc rdx
    mov [rel source_position], rdx
    ret

.end:
    mov eax, SOURCE_EOF
    ret

; Returns the next character without advancing.
source_peek:
    mov rdx, [rel source_position]
    cmp rdx, [rel source_length]
    jae .end

    lea rcx, [rel source_buffer]
    movzx eax, byte [rcx + rdx]
    ret

.end:
    mov eax, SOURCE_EOF
    ret

; Returns the current position.
source_get_position:
    mov rax, [rel source_position]
    ret

; rdi = new position
; returns 0 on success, negative on invalid position
source_set_position:
    cmp rdi, [rel source_length]
    ja .invalid

    mov [rel source_position], rdi
    xor eax, eax
    ret

.invalid:
    mov rax, -22
    ret

source_reset:
    mov qword [rel source_position], 0
    ret

source_stop:
    mov rax, [rel source_length]
    mov [rel source_position], rax
    ret

; rdi = filename
; rsi = character-handler function
;
; The handler receives:
;   al  = character
;   dil = character
;
; returns 0 on success or a negative error
source_for_each:
    mov [rel source_callback], rsi

    call source_load
    test rax, rax
    js .return

.loop:
    call source_next

    cmp eax, SOURCE_EOF
    je .finished

    mov edi, eax
    call qword [rel source_callback]

    jmp .loop

.finished:
    xor eax, eax

.return:
    ret

%endif

global read_char
global read_word
global write_stdout
global print_char
global print_uint
global print_int

section .text
read_char:
    sub rsp, 8
.retry:
    xor eax, eax
    xor edi, edi
    mov rsi, rsp
    mov edx, 1
    syscall

    cmp rax, 1
    je .got_character
    cmp rax, -4
    je .retry

    xor eax, eax
    add rsp, 8
    ret

.got_character:
    movzx eax, byte [rsp]
    add rsp, 8
    ret
read_word:
    push r12
    push r13
    push r14

    mov r12, rdi
    mov r13, rsi
    xor r14d, r14d

    test r13, r13
    jz .fail_no_buffer

.skip_whitespace:
    call read_char
    test eax, eax
    jz .eof_before_word

    cmp al, ' '
    je .skip_whitespace
    cmp al, 9
    jb .have_character
    cmp al, 13
    jbe .skip_whitespace

.have_character:
.store_loop:
    lea rcx, [r14 + 1]
    cmp rcx, r13
    jae .overflow

    mov byte [r12 + r14], al
    inc r14

    call read_char
    test eax, eax
    jz .success

    cmp al, ' '
    je .success
    cmp al, 9
    jb .store_loop
    cmp al, 13
    jbe .success
    jmp .store_loop

.overflow:
    mov byte [r12 + r14], 0

.discard_rest:
    call read_char
    test eax, eax
    jz .failure

    cmp al, ' '
    je .failure
    cmp al, 9
    jb .discard_rest
    cmp al, 13
    jbe .failure
    jmp .discard_rest

.eof_before_word:
    mov byte [r12], 0
.failure:
    xor eax, eax
    jmp .done

.fail_no_buffer:
    xor eax, eax
    jmp .done

.success:
    mov byte [r12 + r14], 0
    mov rax, r12

.done:
    pop r14
    pop r13
    pop r12
    ret

write_stdout:
    mov r8, rdx
.loop:
    test rdx, rdx
    jz .done
.retry:
    mov eax, 1
    mov edi, 1
    syscall

    cmp rax, -4
    je .retry
    test rax, rax
    js .error
    jz .done

    add rsi, rax
    sub rdx, rax
    jmp .loop
.done:
    mov rax, r8
    sub rax, rdx
.error:
    ret

print_char:
    sub rsp, 8
    mov byte [rsp], dil
    mov rsi, rsp
    mov edx, 1
    call write_stdout
    add rsp, 8
    ret

print_uint:
    sub rsp, 40
    lea rsi, [rsp + 40]

    mov rax, rdi
    mov ecx, 10
    test rax, rax
    jne .convert

    dec rsi
    mov byte [rsi], '0'
    mov edx, 1
    jmp .write

.convert:
    xor edx, edx
    div rcx
    add dl, '0'
    dec rsi
    mov byte [rsi], dl
    test rax, rax
    jne .convert

    lea rdx, [rsp + 40]
    sub rdx, rsi

.write:
    call write_stdout
    add rsp, 40
    ret

print_int:
    test rdi, rdi
    jns .nonnegative

    mov rax, rdi
    neg rax
    push rax
    mov edi, '-'
    call print_char
    pop rdi

.nonnegative:
    jmp print_uint

%include "source_reader.asm"
%include "iostream.asm"

section .data
    file_name: db "testcode.txt", 0

section .bss
    variable_values: resq 46
    variable_used: resb 46
    command_buffer: resb 16
    command_length: resq 1
    input_buffer: resb 256
section .text
global _start

_start:
    PROCESS_SOURCE file_name, handle_character

    mov eax, 60
    xor edi, edi
    syscall

handle_character: ;dil
    cmp dil, ' '
    jbe .ignore
    mov rcx, [rel command_length]
    lea rax, [rel command_buffer]
    mov [rax + rcx], dil
    inc rcx
    mov [rel command_length], rcx
    call try_interpret_command
.ignore:
    ret

validate_variable_name:
    cmp dil, 'G'
    jb .failure
    cmp dil, 'Z'
    ja .lowercase
    jmp .success
.lowercase:
    cmp dil, 'a'
    jb .failure
    cmp dil, 'z'
    ja .failure
.success:
    cmp dil, 'Z'
    ja .lbl1
.lbl2:
    sub dil, 'G'
    add dil, 26
    movzx eax, dil
    clc
    ret
.lbl1:
    sub dil, 'a'
    movzx eax, dil
    clc
    ret
.failure:
    stc
    ret

try_interpret_command:
    cmp qword[rel command_length], 3
    jne .not_ready
    mov al, [rel command_buffer]
    mov bl, [rel command_buffer + 1]
    mov cl, [rel command_buffer + 2]
    mov qword[rel command_length], 0
    cmp al, '#'
    je .first_char_print
    cmp bl, '='
    je .call_assignment
    cmp bl, '+'
    je .call_plus
    cmp bl, '-'
    je .call_minus
    cmp bl, '*'
    je .call_multiply
    cmp bl, '/'
    je .call_division
    cmp bl, '%'
    je .call_modulo
    cmp bl, '<'
    je .call_less_than
    cmp bl, '>'
    je .call_greater_than
    jmp .not_ready
.call_assignment:
    mov dil, al
    mov rsi, rcx
    call assignment
    jmp .not_ready
.call_plus:
    mov dil, al
    mov rsi, rcx
    call plus
    jmp .not_ready
.call_minus:
    mov dil, al
    mov rsi, rcx
    call minus
    jmp .not_ready
.call_multiply:
    mov dil, al
    mov rsi, rcx
    call multiply
    jmp .not_ready
.call_division:
    mov dil, al
    mov rsi, rcx
    call division
    jmp .not_ready
.call_modulo:
    mov dil, al
    mov rsi, rcx
    call modulo
    jmp .not_ready
.call_less_than:
    mov dil, al
    mov rsi, rcx
    call less_than
    jmp .not_ready
.call_greater_than:
    mov dil, al
    mov rsi, rcx
    call greater_than
    jmp .not_ready
.first_char_print:
    cmp bl, 'd'
    je .second_char_print_decimal
    cmp bl, 'c'
    je .second_char_print_char
    jmp .not_ready
.second_char_print_decimal:
    movzx edi, cl
    call validate_variable_name
    jc .not_ready
    mov rdi, rax
    call print_decimal_variable
    jmp .not_ready
.second_char_print_char:
    movzx edi, cl
    call validate_variable_name
    jc .not_ready
    mov rdi, rax
    call print_char_variable
    jmp .not_ready
.not_ready:
    ret

assignment:
    push rdi
    push rsi
    call validate_variable_name
    jc .restore
    mov r8, rax
    mov rdi, rsi
    call validate_variable_name
    jc .not_variable
    mov r9, rax
    mov rdi, r8
    mov rsi, r9
    call assignment_variable
    pop rsi
    pop rdi
    jmp .terminate
.not_variable:
    pop rsi
    pop rdi
    cmp sil, '.'
    je .input
    jmp .value
.input:
    mov rdi, r8
    call assignment_input
    jmp .terminate
.value:
    mov rdi, r8
    call assignment_hexadecimal
    jmp .terminate
.restore:
    pop rsi
    pop rdi
    jmp .terminate
.terminate:
    ret

assignment_variable:
    mov rax, [variable_values + rsi*8]
    mov [variable_values + rdi*8], rax
    mov [variable_used + rdi], 1
    ret

assignment_input:
    push rdi
    lea rdi, [rel input_buffer]
    mov rsi, 256
    call read_word
    mov rdi, rax
    call parse_int
    test rdx, rdx
    jz .lbl1
    jmp .lbl2
.lbl1:
    mov rax, [input_buffer]
.lbl2:
    pop rdi
    mov [variable_values + rdi*8], rax
    mov byte[variable_used + rdi], 1
    ret

assignment_hexadecimal:
    cmp rsi, '9'
    ja .big_digit
.small_digit:
    mov rax, rsi
    sub rax, '0'
    jmp .assign_value
.big_digit:
    mov rax, rsi
    sub rax, 'A'
    add rax, 10
.assign_value:
    mov [variable_values + rdi * 8], rax
    mov byte[variable_used + rdi], 1
    ret

plus:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    jc .constant
    jmp .variable
.constant:
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call plus_constant
    jmp .terminate
.variable:
    mov rsi, rax
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call plus_variable
    jmp .terminate
.terminate:
    ret

plus_constant:
    cmp rsi, '9'
    ja .big_digit
.small_digit:
    mov rax, rsi
    sub rax, '0'
    jmp .assign_value
.big_digit:
    mov rax, rsi
    sub rax, 'A'
    add rax, 10
.assign_value:
    add [variable_values + rdi * 8], rax
    ret

plus_variable:
    mov rax, [variable_values + rsi * 8]
    add [variable_values + rdi * 8], rax
    ret

minus:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    jc .constant
    jmp .variable
.constant:
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call minus_constant
    jmp .terminate
.variable:
    mov rsi, rax
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call minus_variable
    jmp .terminate
.terminate:
    ret

minus_constant:
    cmp rsi, '9'
    ja .big_digit
.small_digit:
    mov rax, rsi
    sub rax, '0'
    jmp .assign_value
.big_digit:
    mov rax, rsi
    sub rax, 'A'
    add rax, 10
.assign_value:
    sub [variable_values + rdi * 8], rax
    ret

minus_variable:
    mov rax, [variable_values + rsi * 8]
    sub [variable_values + rdi * 8], rax
    ret

multiply:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    jc .constant
    jmp .variable
.constant:
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call multiply_constant
    jmp .terminate
.variable:
    mov rsi, rax
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call multiply_variable
    jmp .terminate
.terminate:
    ret

multiply_constant:
    cmp rsi, '9'
    ja .big_digit
.small_digit:
    mov rax, rsi
    sub rax, '0'
    jmp .assign_value
.big_digit:
    mov rax, rsi
    sub rax, 'A'
    add rax, 10
.assign_value:
    mov rcx, [variable_values + rdi * 8]
    imul rcx, rax
    mov [variable_values + rdi * 8], rcx
    ret

multiply_variable:
    mov rax, [variable_values + rsi * 8]
    mov rcx, [variable_values + rdi * 8]
    imul rcx, rax
    mov [variable_values + rdi * 8], rcx
    ret

division:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    jc .constant
    jmp .variable
.constant:
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call division_constant
    jmp .terminate
.variable:
    mov rsi, rax
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call division_variable
    jmp .terminate
.terminate:
    ret

division_constant:
    cmp rsi, '9'
    ja .big_digit
.small_digit:
    mov rax, rsi
    sub rax, '0'
    jmp .assign_value
.big_digit:
    mov rax, rsi
    sub rax, 'A'
    add rax, 10
.assign_value:
    mov rbx, rax
    mov rax, [variable_values + rdi * 8]
    cqo
    idiv rbx
    mov [variable_values + rdi * 8], rax
    ret

division_variable:
    mov rax, [variable_values + rdi * 8]
    mov rbx, [variable_values + rsi * 8]
    cqo
    idiv rbx
    mov [variable_values + rdi * 8], rax
    ret

modulo:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    jc .constant
    jmp .variable
.constant:
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call modulo_constant
    jmp .terminate
.variable:
    mov rsi, rax
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call modulo_variable
    jmp .terminate
.terminate:
    ret

modulo_constant:
    cmp rsi, '9'
    ja .big_digit
.small_digit:
    mov rax, rsi
    sub rax, '0'
    jmp .assign_value
.big_digit:
    mov rax, rsi
    sub rax, 'A'
    add rax, 10
.assign_value:
    mov rbx, rax
    mov rax, [variable_values + rdi * 8]
    cqo
    idiv rbx
    mov [variable_values + rdi * 8], rdx
    ret

modulo_variable:
    mov rax, [variable_values + rdi * 8]
    mov rbx, [variable_values + rsi * 8]
    cqo
    idiv rbx
    mov [variable_values + rdi * 8], rdx
    ret

less_than:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    jc .constant
    jmp .variable
.constant:
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call less_than_constant
    jmp .terminate
.variable:
    mov rsi, rax
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call less_than_variable
    jmp .terminate
.terminate:
    ret

less_than_constant:
    cmp rsi, '9'
    ja .big_digit
.small_digit:
    mov rax, rsi
    sub rax, '0'
    jmp .assign_value
.big_digit:
    mov rax, rsi
    sub rax, 'A'
    add rax, 10
.assign_value:
    cmp [variable_values + rdi * 8], rax
    jl .return_true
.return_false:
    mov [variable_values + rdi * 8], 0
    ret
.return_true:
    mov [variable_values + rdi * 8], 1
    ret

less_than_variable:
    mov rax, [variable_values + rsi * 8]
    cmp [variable_values + rdi * 8], rax
    jl .return_true
.return_false:
    mov [variable_values + rdi * 8], 0
    ret
.return_true:
    mov [variable_values + rdi * 8], 1
    ret

greater_than:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    jc .constant
    jmp .variable
.constant:
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call greater_than_constant
    jmp .terminate
.variable:
    mov rsi, rax
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call greater_than_variable
    jmp .terminate
.terminate:
    ret

greater_than_constant:
    cmp rsi, '9'
    ja .big_digit
.small_digit:
    mov rax, rsi
    sub rax, '0'
    jmp .assign_value
.big_digit:
    mov rax, rsi
    sub rax, 'A'
    add rax, 10
.assign_value:
    cmp [variable_values + rdi * 8], rax
    jg .return_true
.return_false:
    mov [variable_values + rdi * 8], 0
    ret
.return_true:
    mov [variable_values + rdi * 8], 1
    ret

greater_than_variable:
    mov rax, [variable_values + rsi * 8]
    cmp [variable_values + rdi * 8], rax
    jg .return_true
.return_false:
    mov [variable_values + rdi * 8], 0
    ret
.return_true:
    mov [variable_values + rdi * 8], 1
    ret

print_decimal_variable:
    mov rax, [variable_values + rdi*8]
    mov rdi, rax
    call print_int
    ret

print_char_variable:
    mov rax, [variable_values + rdi*8]
    mov rdi, rax
    call print_char
    ret

parse_int:
    xor eax, eax
    xor edx, edx
    xor r8d, r8d

    movzx ecx, byte [rdi]
    cmp cl, '-'
    je .negative
    cmp cl, '+'
    je .positive_sign
    jmp .after_sign

.negative:
    mov r8d, 1
    inc rdx
    jmp .after_sign

.positive_sign:
    inc rdx

.after_sign:
    mov r9, rdx

.digit_loop:
    movzx ecx, byte [rdi + rdx]
    sub ecx, '0'
    cmp ecx, 9
    ja .digits_done

    imul rax, rax, 10
    add rax, rcx
    inc rdx
    jmp .digit_loop

.digits_done:
    cmp rdx, r9
    jne .have_digits

    xor eax, eax
    xor edx, edx
    ret

.have_digits:
    test r8d, r8d
    jz .done
    neg rax
.done:
    ret

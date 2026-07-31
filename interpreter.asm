%include "source_reader.asm"
%include "iostream.asm"

section .bss
    variable_values: resq 46 * 16
    variable_indices: resq 46
    command_buffer: resb 16
    command_length: resq 1
    input_buffer: resb 256
    characters_to_skip: resb 1
    label_positions: resq 46
    label_defined: resb 46
    label_scan_buffer: resb 3
    label_scan_length: resq 1
section .text
global _start

_start:
    cmp qword [rsp], 2
    jb .exit_error
    mov rdi, [rsp + 16]
    call source_load
    test rax, rax
    js .exit_error

    call scan_labels
    call source_reset

.execute:
    call source_next
    cmp eax, SOURCE_EOF
    je .exit_success

    mov edi, eax
    call handle_character
    jmp .execute

.exit_error:
    mov edi, 1
    jmp .exit

.exit_success:
    xor edi, edi

.exit:
    mov eax, 60
    syscall

get_memory_address:
    mov r8, [variable_indices + rdi*8]
    shl rdi, 7
    shl r8, 3
    add rdi, r8
    lea rax, [rel variable_values]
    add rax, rdi
    ret

scan_labels:
    call source_reset
    mov qword [rel label_scan_length], 0

.next_character:
    call source_next
    cmp eax, SOURCE_EOF
    je .done

    cmp al, ' '
    jbe .next_character

    mov rcx, [rel label_scan_length]
    lea rdx, [rel label_scan_buffer]
    mov [rdx + rcx], al
    inc rcx
    mov [rel label_scan_length], rcx

    cmp rcx, 3
    jne .next_character

    mov qword [rel label_scan_length], 0
    cmp byte [rel label_scan_buffer], ':'
    jne .next_character
    cmp byte [rel label_scan_buffer + 2], ':'
    jne .next_character

    call source_get_position
    mov r9, rax

    movzx edi, byte [rel label_scan_buffer + 1]
    call validate_variable_name
    jc .next_character

    lea rdx, [rel label_positions]
    mov [rdx + rax * 8], r9
    lea rdx, [rel label_defined]
    mov byte [rdx + rax], 1
    jmp .next_character

.done:
    call source_reset
    mov qword [rel command_length], 0
    ret

handle_character: ;dil
    cmp dil, ' '
    jbe .ignore

    cmp byte [rel characters_to_skip], 0
    ja .skip

    mov rcx, [rel command_length]
    lea rax, [rel command_buffer]
    mov [rax + rcx], dil
    inc rcx
    mov [rel command_length], rcx
    call try_interpret_command
    jmp .ignore

.skip:
    dec byte [rel characters_to_skip]

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
    cmp al, ':'
    je .not_ready
    cmp al, '@'
    je .call_goto
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
    cmp bl, '~'
    je .call_equal_to
    cmp bl, '!'
    je .call_not_equal
    cmp bl, '?'
    je .call_if
    cmp bl, '['
    je .call_at
    cmp bl, '&'
    je .call_and
    cmp bl, '|'
    je .call_or
    cmp bl, '^'
    je .call_xor
    cmp bl, '{'
    je .call_shift_left
    cmp bl, '}'
    je .call_shift_right
    jmp .not_ready
.call_goto:
    mov dil, bl
    call goto_label
    jmp .not_ready
.call_assignment:
    mov dil, al
    movzx esi, cl
    call assignment
    jmp .not_ready
.call_plus:
    mov dil, al
    movzx esi, cl
    call plus
    jmp .not_ready
.call_minus:
    mov dil, al
    movzx esi, cl
    call minus
    jmp .not_ready
.call_multiply:
    mov dil, al
    movzx esi, cl
    call multiply
    jmp .not_ready
.call_division:
    mov dil, al
    movzx esi, cl
    call division
    jmp .not_ready
.call_modulo:
    mov dil, al
    movzx esi, cl
    call modulo
    jmp .not_ready
.call_less_than:
    mov dil, al
    movzx esi, cl
    call less_than
    jmp .not_ready
.call_greater_than:
    mov dil, al
    movzx esi, cl
    call greater_than
    jmp .not_ready
.call_equal_to:
    mov dil, al
    movzx esi, cl
    call equal_to
    jmp .not_ready
.call_not_equal:
    mov dil, al
    movzx esi, cl
    call not_equal
    jmp .not_ready
.call_if:
    mov dil, al
    call if
    jmp .not_ready
.call_at:
    mov dil, al
    movzx esi, cl
    call at_operator
    jmp .not_ready
.call_and:
    mov dil, al
    movzx esi, cl
    mov rdx, 0
    call bit_operator
    jmp .not_ready
.call_or:
    mov dil, al
    movzx esi, cl
    mov rdx, 1
    call bit_operator
    jmp .not_ready
.call_xor:
    mov dil, al
    movzx esi, cl
    mov rdx, 2
    call bit_operator
    jmp .not_ready
.call_shift_left:
    mov dil, al
    movzx esi, cl
    mov rdx, 3
    call bit_operator
    jmp .not_ready
.call_shift_right:
    mov dil, al
    movzx esi, cl
    mov rdx, 4
    call bit_operator
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

goto_label:
    call validate_variable_name
    jc .terminate

    lea rdx, [rel label_defined]
    cmp byte [rdx + rax], 0
    je .terminate

    lea rdx, [rel label_positions]
    mov rdi, [rdx + rax * 8]
    call source_set_position

.terminate:
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
    xchg rdi, rsi
    call get_memory_address
    mov r9, [rax]
    mov rdi, rsi
    call get_memory_address
    mov [rax], r9
    ret

assignment_input:
    push rdi
    lea rdi, [rel input_buffer]
    mov esi, 256
    call read_word
    test rax, rax
    jz .input_failed
    mov rdi, rax
    call parse_int
    test rdx, rdx
    jnz .store
    movzx eax, byte [rel input_buffer]
.store:
    pop rdi
    push rax
    call get_memory_address
    pop qword [rax]
    ret
.input_failed:
    pop rdi
    ret

assignment_hexadecimal:
    sub rsi, '0'
    cmp rsi, 9
    jbe .store
    sub rsi, 7
.store:
    call get_memory_address
    mov [rax], rsi
    ret

plus:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    mov rdi, r8
    jc .constant
    mov rsi, rax
    call validate_variable_name
    mov rdi, rax
    jmp plus_variable
.constant:
    call validate_variable_name
    mov rdi, rax
    jmp plus_constant

plus_constant:
    movzx ecx, sil
    sub rcx, '0'
    cmp rcx, 9
    jbe .add
    sub rcx, 7
.add:
    call get_memory_address
    add [rax], rcx
    ret

plus_variable:
    xchg rdi, rsi
    call get_memory_address
    mov rbx, [rax]
    xchg rdi, rsi
    call get_memory_address
    add [rax], rbx
    ret

minus:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    mov rdi, r8
    jc .constant
    mov rsi, rax
    call validate_variable_name
    mov rdi, rax
    jmp minus_variable
.constant:
    call validate_variable_name
    mov rdi, rax
    jmp minus_constant

minus_constant:
    movzx ecx, sil
    sub rcx, '0'
    cmp rcx, 9
    jbe .add
    sub rcx, 7
.add:
    call get_memory_address
    sub [rax], rcx
    ret

minus_variable:
    xchg rdi, rsi
    call get_memory_address
    mov rbx, [rax]
    xchg rdi, rsi
    call get_memory_address
    sub [rax], rbx
    ret

multiply:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    mov rdi, r8
    jc .constant
    mov rsi, rax
    call validate_variable_name
    mov rdi, rax
    jmp multiply_variable
.constant:
    call validate_variable_name
    mov rdi, rax
    jmp multiply_constant

multiply_constant:
    movzx ecx, sil
    sub rcx, '0'
    cmp rcx, 9
    jbe .add
    sub rcx, 7
.add:
    call get_memory_address
    imul rcx, [rax]
    mov [rax], rcx
    ret

multiply_variable:
    xchg rdi, rsi
    call get_memory_address
    mov rbx, [rax]
    xchg rdi, rsi
    call get_memory_address
    imul rbx, [rax]
    mov [rax], rbx
    ret

division:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    mov rdi, r8
    jc .constant
    mov rsi, rax
    call validate_variable_name
    mov rdi, rax
    jmp division_variable
.constant:
    call validate_variable_name
    mov rdi, rax
    jmp division_constant

division_constant:
    movzx ecx, sil
    sub rcx, '0'
    cmp rcx, 9
    jbe .add
    sub rcx, 7
.add:
    call get_memory_address
    push rax
    mov rax, [rax]
    cqo
    idiv rcx
    mov r8, rax
    pop rax
    mov [rax], r8
    ret

division_variable:
    call get_memory_address
    mov r9, rax
    mov rdi, rsi
    call get_memory_address
    mov r10, rax
    mov rax, [r9]
    mov rbx, [r10]
    cqo
    idiv rbx
    mov [r9], rax
    ret

modulo:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    mov rdi, r8
    jc .constant
    mov rsi, rax
    call validate_variable_name
    mov rdi, rax
    jmp modulo_variable
.constant:
    call validate_variable_name
    mov rdi, rax
    jmp modulo_constant

modulo_constant:
    movzx ecx, sil
    sub rcx, '0'
    cmp rcx, 9
    jbe .add
    sub rcx, 7
.add:
    call get_memory_address
    push rax
    mov rax, [rax]
    cqo
    idiv rcx
    mov r8, rdx
    pop rax
    mov [rax], r8
    ret

modulo_variable:
    call get_memory_address
    mov r9, rax
    mov rdi, rsi
    call get_memory_address
    mov r10, rax
    mov rax, [r9]
    mov rbx, [r10]
    cqo
    idiv rbx
    mov [r9], rdx
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
    movzx ecx, sil
    sub ecx, '0'
    cmp ecx, 9
    jbe .compare
    sub ecx, 7
.compare:
    call get_memory_address
    cmp qword [rax], rcx
    setl cl
    movzx ecx, cl
    mov [rax], rcx
    ret

less_than_variable:
    xchg rdi, rsi
    call get_memory_address
    mov rcx, [rax]
    xchg rdi, rsi
    call get_memory_address
    cmp [rax], rcx
    setl cl
    movzx ecx, cl
    mov [rax], rcx
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
    movzx ecx, sil
    sub ecx, '0'
    cmp ecx, 9
    jbe .compare
    sub ecx, 7
.compare:
    call get_memory_address
    cmp rcx, qword [rax]
    setl cl
    movzx ecx, cl
    mov [rax], rcx
    ret

greater_than_variable:
    xchg rdi, rsi
    call get_memory_address
    mov rcx, [rax]
    xchg rdi, rsi
    call get_memory_address
    cmp rcx, [rax]
    setl cl
    movzx ecx, cl
    mov [rax], rcx
    ret

equal_to:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    jc .constant
    jmp .variable
.constant:
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call equal_to_constant
    jmp .terminate
.variable:
    mov rsi, rax
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call equal_to_variable
    jmp .terminate
.terminate:
    ret

equal_to_constant:
    movzx ecx, sil
    sub ecx, '0'
    cmp ecx, 9
    jbe .compare
    sub ecx, 7
.compare:
    call get_memory_address
    cmp rcx, qword [rax]
    sete cl
    movzx ecx, cl
    mov [rax], rcx
    ret

equal_to_variable:
    xchg rdi, rsi
    call get_memory_address
    mov rcx, [rax]
    xchg rdi, rsi
    call get_memory_address
    cmp rcx, [rax]
    sete cl
    movzx ecx, cl
    mov [rax], rcx
    ret

not_equal:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    jc .constant
    jmp .variable
.constant:
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call not_equal_constant
    jmp .terminate
.variable:
    mov rsi, rax
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call not_equal_variable
    jmp .terminate
.terminate:
    ret

not_equal_constant:
    movzx ecx, sil
    sub ecx, '0'
    cmp ecx, 9
    jbe .compare
    sub ecx, 7
.compare:
    call get_memory_address
    cmp rcx, qword [rax]
    setne cl
    movzx ecx, cl
    mov [rax], rcx
    ret

not_equal_variable:
    xchg rdi, rsi
    call get_memory_address
    mov rcx, [rax]
    xchg rdi, rsi
    call get_memory_address
    cmp rcx, [rax]
    setne cl
    movzx ecx, cl
    mov [rax], rcx
    ret

if:
    call validate_variable_name
    mov rdi, rax
    call get_memory_address
    mov rcx, [rax]
    test rcx, rcx
    jnz .terminate
.skip_instruction:
    mov byte [rel characters_to_skip], 3
.terminate:
    ret

at_operator:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    jc .constant
    jmp .variable
.constant:
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call at_constant
    jmp .terminate
.variable:
    mov rsi, rax
    mov rdi, r8
    call validate_variable_name
    mov rdi, rax
    call at_variable
    jmp .terminate
.terminate:
    ret

at_constant:
    movzx ecx, sil
    sub ecx, '0'
    cmp ecx, 9
    jbe .set_index
    sub ecx, 7
.set_index:
    mov [variable_indices + rdi * 8], rcx
    ret

at_variable:
    xchg rdi, rsi
    call get_memory_address
    mov rax, [rax]
    mov [variable_indices + rsi * 8], rax
    ret

bit_operator:
    mov r8, rdi
    mov rdi, rsi
    call validate_variable_name
    mov rdi, r8
    jc .constant
    mov rsi, rax
    call validate_variable_name
    mov rdi, rax
    jmp bit_variable
.constant:
    call validate_variable_name
    mov rdi, rax
    jmp bit_constant

bit_constant:
    movzx ecx, sil
    sub rcx, '0'
    cmp rcx, 9
    jbe .perform
    sub rcx, 7
.perform:
    call get_memory_address
    cmp rdx, 0
    je .and
    cmp rdx, 1
    je .or
    cmp rdx, 2
    je .xor
    cmp rdx, 3
    je .left
    cmp rdx, 4
    je .right
    ret
.and:
    and [rax], rcx
    ret
.or:
    or [rax], rcx
    ret
.xor:
    xor [rax], rcx
    ret
.left:
    sal qword [rax], cl
    ret
.right:
    sar qword [rax], cl
    ret

bit_variable:
    xchg rdi, rsi
    call get_memory_address
    mov rcx, [rax]
    xchg rdi, rsi
    call get_memory_address
    cmp rdx, 0
    je .and
    cmp rdx, 1
    je .or
    cmp rdx, 2
    je .xor
    cmp rdx, 3
    je .left
    cmp rdx, 4
    je .right
    ret
.and:
    and [rax], rcx
    ret
.or:
    or [rax], rcx
    ret
.xor:
    xor [rax], rcx
    ret
.left:
    sal qword [rax], cl
    ret
.right:
    sar qword [rax], cl
    ret

print_decimal_variable:
    call get_memory_address
    mov rdi, [rax]
    call print_int
    ret

print_char_variable:
    call get_memory_address
    mov rdi, [rax]
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

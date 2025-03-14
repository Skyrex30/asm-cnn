; Compile:
; nasm -f win32 projekt.asm
; nlink projekt.obj -lgfx -lio -lmio -o projekt.exe

%include 'io.inc'
%include 'gfx.inc'
%include 'util.inc'

%define WIDTH  224        
%define HEIGHT 264        ; 40 pixels for the buttons

%define BUTTON1_X 0
%define BUTTON1_Y 224
%define BUTTON1_WIDTH WIDTH
%define BUTTON1_HEIGHT 20

%define BUTTON2_X 0
%define BUTTON2_Y 244
%define BUTTON2_WIDTH WIDTH
%define BUTTON2_HEIGHT 20

%define WHITE_COLOR 0x00FFFFFF
%define GREEN_BUTTON_COLOR 0x0000FF00
%define RED_BUTTON_COLOR 0x00FF0000

global main

section .text
main:
    call    draw_menu          ; Draw menu
	call    event_loop
	
    ret

; Function to handle mouse events
; ----------------------------------------------------------------------------------------

event_loop:
    .wait_event:
        call gfx_getevent         ; Wait for an event
        test eax, eax             ; If no event, exit the loop
        jz .wait_event            ; Keep waiting if no event

        cmp	 eax, 23			 ; the window close button was pressed: exit
        je	.exit_program
        
        cmp  eax, 1                ; Check if it's the left mouse button press
        jne .wait_event           ; Ignore if it's not a left click

        call gfx_getmouse         ; Get the mouse coordinates
       
        mov ecx, ebx              ; Store Y coordinate in ECX
        mov ebx, eax              ; Store X coordinate in EBX

        ; Check if the green button is pressed
        cmp ecx, BUTTON1_Y        ; Is Y within button 1's range?
        jl .check_red_button      ; If Y is lower than button 1, check red button
        cmp ecx, BUTTON1_Y + BUTTON1_HEIGHT
        jge .check_red_button
        cmp ebx, BUTTON1_X        ; Is X within button 1's range?
        jl .check_red_button
        cmp ebx, BUTTON1_X + BUTTON1_WIDTH
        jge .check_red_button

        ; Green button pressed, call detect
        call detect
        jmp .wait_event           ; Go back to wait for the next event

    .check_red_button:
        ; Check if the red button is pressed
        cmp ecx, BUTTON2_Y        ; Is Y within button 2's range?
        jl .draw_white_pixel      ; If Y is lower than button 2, draw a white pixel
        cmp ecx, BUTTON2_Y + BUTTON2_HEIGHT
        jge .draw_white_pixel
        cmp ebx, BUTTON2_X        ; Is X within button 2's range?
        jl .draw_white_pixel
        cmp ebx, BUTTON2_X + BUTTON2_WIDTH
        jge .draw_white_pixel

        ; Red button pressed, exit the program
        .exit_program:
        call gfx_destroy
        ret

    .draw_white_pixel:
        ; Draw a white pixel where the mouse was clicked
        call gfx_map                ; Map the framebuffer
        mov edi, eax                ; Store framebuffer pointer
        imul ecx, WIDTH             ; ECX = Y * WIDTH
        add ecx, ebx                ; ECX = Y * WIDTH + X (mouse pos)
        shl ecx, 2
        add edi, ecx                ; Move pointer to pixel position

        mov eax, WHITE_COLOR        ; White color
        mov [edi], eax              ; Write the pixel

        call gfx_unmap              ; Unmap the framebuffer
        call gfx_draw               ; Redraw the screen
        jmp .wait_event             ; Go back to wait for another event
    
; ----------------------------------------------------------------------------------------
; Function to detect a number
detect:
    mov eax, detectionmsg
    call io_writestr
    call io_writeln

    call store_drawing_zone
    call resize_to_28x28           ; Resize the drawing area to 28x28
    call scale_image
    mov eax, [lin_model_txt]
    mov ebx, [lin_model_bin]
    call initialize_cnn


    ret
; ----------------------------------------------------------------------------------------
; Function to store the drawing zone


store_drawing_zone:
    call gfx_map
    mov esi, eax                 ; ESI = framebuffer pointer (top-left pixel)
    mov edi, draw_zone          ; EDI = address of the drawing zone 
    xor ecx, ecx                 ; ECX = Y (row counter)

.store_rows:
    cmp ecx, 224                 ; Loop through each row
    jge .end_store               ; Stop if Y >= 224

    xor edx, edx                 ; EDX = X (column counter)

.store_columns:
    cmp edx, 224                 ; Loop through each column
    jge .next_row

    mov eax, [esi]
    mov [edi], eax               ; Store the pixel value in the draw_zone buffer

    add esi, 4                  ; Next pixel in the framebuffer
    add edi, 4                   ; Next position in the buffer

    inc edx
    jmp .store_columns

.next_row:
    inc ecx
    jmp .store_rows

.end_store:
    call gfx_unmap
    ret
;----------------------------------------------------------------------------------------
; Function to resize the drawing zone to 28x28

resize_to_28x28:
    mov esi, draw_zone         ; ESI = pointer to the 224x224 source image
    mov edi, resized_zone      ; EDI = pointer to the 28x28 destination image
    
        xor ebx, ebx               ; Outer loop counter for rows (Y in 28x28)
.outer_loop:
    cmp ebx, 28                ; Limit to 28 rows
    jge .done_resize           ; Exit loop if done

    mov ecx, 28                ; Inner loop counter for columns (X in 28x28)
    xor edx, edx               ; Column counter for source image

.inner_loop:
    cmp edx, 28                ; Limit to 28 columns
    jge .next_row

    ; Calculate the source pixel coordinates in 224x224
    mov eax, ebx
    shl eax, 3                 ; eax = Y * 8 (scale factor)
    imul eax, WIDTH            ; eax = (Y * 8) * WIDTH

    mov ecx, edx
    shl ecx, 3                 ; ecx = X * 8 (scale factor)
    add eax, ecx               ; eax = (Y * 8 * WIDTH) + (X * 8)
    shl eax, 2                 ; Multiply by 4 (pixel size)
    add eax, esi               ; eax = source address

    ; Copy the pixel value
    mov ecx, [eax]             ; Load pixel
    mov [edi], ecx             ; Store pixel

    add edi, 4                 ; Move to next pixel in destination buffer
    inc edx                    ; Increment X (28x28)
    jmp .inner_loop

.next_row:
    inc ebx                    ; Increment Y (28x28)
    jmp .outer_loop

.done_resize:
    ret
;----------------------------------------------------------------------------------------
; Function to scale the image to floats [-1, 1]

scale_image:
    mov ecx, 784                ; Loop counter for 28x28 pixels
    mov esi, resized_zone        ; Source image array (color values)
    mov edi, scaled_array        ; Destination array (scaled values)

.loop_pixels:
    ; Load the pixel color (4 bytes: 0x00RRGGBB)
    mov eax, [esi]               ; Get pixel color
    add esi, 4                   ; Move to the next pixel

    ; Check if the pixel is black (0x000000)
    test eax, eax                ; If eax is 0, the pixel is black
    jz .store_neg_one

    ; Otherwise, store 1.0 (for white pixels)
    fld dword [one]              ; Load 1.0 (white) into FPU
    jmp .store_pixel

.store_neg_one:
    fld dword [neg_one]          ; Load -1.0 (black) into FPU

.store_pixel:
    fstp dword [edi]             ; Store the float value in the scaled array
    add edi, 4                   ; Move to the next position in the scaled array

    dec ecx
    jnz .loop_pixels             ; Loop until all pixels are processed

    ret

; ----------------------------------------------------------------------------------------
; CNN Initialization
initialize_cnn:
    ; Arguments:
    ;   eax - Pointer to structure file (.txt) name
    ;   ebx - Pointer to binary weights file (.bin) name

    push ecx
    push edx
    push esi
    push edi

    ; Open the structure file
    push  ebx
    mov ebx, 0                ; Open mode: read
    call fio_open
    test eax, eax             ; Check if file opened successfully
    jz .error_structure
    pop ebx
    mov esi, eax              ; Save file handle for the structure file

    ; Open the binary weights file
    mov eax, ebx              ; Binary weights file name
    mov ebx, 0
    call fio_open
    test eax, eax             ; Check if file opened successfully
    jz .error_weights
    mov edi, eax              ; Save file handle for the binary file

    ; Initialize counters
    mov [conv_count], dword 0
    mov [linear_count], dword 0
    mov [conv_size], dword 0
    mov [linear_size], dword 0

    ; Parse the structure file
    .parse_structure:
        ; Read a chunk of the structure file
        mov eax, esi          ; File handle
        mov ebx, structure_buffer ; Buffer pointer
        mov ecx, buffer_size  ; Size to read
        call fio_read
        test edx, edx         ; Check if end of file
        jz .done_parsing

        ; Process the buffer line by line
        mov esi, structure_buffer
    .process_line:
        ; Find the end of the current line
        mov edi, esi
    .find_line_end:
        cmp byte [edi], 0
        jz .done_parsing       ; End of buffer
        cmp byte [edi], 10     ; Newline character
        je .line_found
        inc edi
        jmp .find_line_end

    .line_found:
        ; Null-terminate
        mov byte [edi], 0

        ; Compare line with prefixes
        ; mov eax, esi
        ; call compare_conv_prefix
        ; test eax, eax
        ; jz .process_conv       ; Line starts with "Conv"

        mov eax, esi
        call compare_linear_prefix
        test eax, eax
        jz .process_linear     ; Line starts with "Linear"

        mov eax, esi
        call compare_relu_prefix
        test eax, eax
        jz .process_relu     ; Line starts with "Relu"

        mov eax, esi
        call compare_argmax_prefix
        test eax, eax
        jz .process_argmax    ; Line starts with "Argmax"

        mov eax, esi
        call compare_maxpool_prefix
        test eax, eax
        jz .process_maxpool     ; Line starts with "Maxpool"

        ; Skip to next line
        add edi, 1
        mov esi, edi
        jmp .process_line

    .process_relu:
        call relu_layer
        jmp .next_line
    .process_argmax:
        call argmax_layer
        mov  ebx, [eax]
        mov eax, ebx
        call io_writeint
        ret
    .process_maxpool:
        ; call maxpool_layer
        jmp .next_line

    .process_conv:
        ; Parse Conv layer parameters
        call parse_conv_params
        ; Calculate memory size for weights and biases
        ; Total Size (bytes)=(conv_in×conv_out×3×3×4)+(conv_out×4)
        mov eax, conv_in           ; Input channels
        imul eax, conv_out         ; Multiply by output channels
        imul eax, 36               ; Multiply by kernel size (3x3 = 9 elements, 4 bytes each)
        mov ebx, conv_out
        imul ebx, 4                ; Bias 
        add eax, ebx               ; Add bias size (4 bytes per output channel)
        add [conv_size], eax         ; Increment total size to skip
        ; Allocate memory for weights and biases
        call alloc_conv_layer
        add byte [conv_count], 1
        jmp .next_line

    .process_linear:
        ; Parse Linear layer parameters
        call parse_linear_params

        ; Allocate memory for weights and biases
        call alloc_linear_layer
        add word [linear_count], 1

        ; Set arguments for linear_layer
        mov esi, input_vector       ; Input vector pointer
        mov edi, output_vector      ; Output vector pointer
        mov ebx, [weights_pointer]  ; Weights pointer
        mov ecx, [bias_pointer]     ; Bias pointer

        ; Call linear layer processing
        call linear_layer

        ; Move output to input for the next layer
        mov esi, output_vector
        mov edi, input_vector
        mov ecx, linear_out         ; Number of elements to copy
    .copy_output_to_input:
        mov eax, [esi]
        mov [edi], eax
        add esi, 4
        add edi, 4
        loop .copy_output_to_input

        jmp .next_line


    .next_line:
        ; Move to the next line
        add edi, 1
        mov esi, edi
        jmp .process_line

    .done_parsing:
        ; Close the structure and binary files
        mov eax, esi
        call fio_close
        mov eax, edi
        call fio_close
        jmp .done_init

    .error_structure:
        ; Handle structure file open error
        mov eax, error_structure_msg
        call io_writestr
        jmp .cleanup

    .error_weights:
        ; Handle binary file open error
        mov eax, error_weights_msg
        call io_writestr
        jmp .cleanup

    .cleanup:
        ; Close any open files
        test esi, esi
        jz .close_weights
        mov eax, esi
        call fio_close

    .close_weights:
        test edi, edi
        jz .done_init
        mov eax, edi
        call fio_close

    .done_init:
        pop edi
        pop esi
        pop edx
        pop ecx
        ret

; Allocate memory for a linear layer
alloc_linear_layer:
    ; Assumes linear_in and linear_out are already set
    ; Arguments:
    ;   edi - Binary file handle

    push ebx                   ; Save registers
    push ecx
    push edx
    push esi

    ; Calculate memory size for weights and biases
    mov eax, linear_in
    imul eax, linear_out       ; Total elements in weight matrix
    imul eax, 4                ; Multiply by 4 bytes per float
    mov ebx, linear_out
    imul ebx, 4
    add eax, ebx               ; Total memory size = weights + biases

    call mem_alloc
    test eax, eax              ; Check allocation success
    jz .alloc_error
    mov esi, eax               ; Save allocated base pointer

    ; Save pointers for weights and biases
    mov [weights_pointer], esi ; Save weights pointer
    mov eax, linear_in
    imul eax, linear_out
    imul eax, 4
    add esi, eax               ; Move to bias location
    mov [bias_pointer], esi    ; Save biases pointer

    ; Read weights from binary file
    mov eax, linear_in
    imul eax, linear_out       ; Total elements in weight matrix
    imul eax, 4
    mov ebx, [weights_pointer] ; Pointer to allocated weights memory
    call fio_read              ; Read weights

    ; Read biases from binary file
    mov eax, linear_out        ; Number of biases
    imul eax, 4
    mov ebx, [bias_pointer]    ; Pointer to allocated biases memory
    call fio_read              ; Read biases

    jmp .done

.alloc_error:
    mov eax, error_alloc_msg
    call io_writestr

.done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret


; Allocate memory and load parameters for Conv layer
alloc_conv_layer:
    ; Assumes conv_in and conv_out are already set
    ; Arguments:
    ;   eax - Binary file handle

    push ebx                   ; Save registers
    push ecx
    push edx
    push esi

    ; Calculate memory size for weights and biases
    mov eax, conv_in           ; Input channels
    imul eax, conv_out         ; Multiply by output channels
    imul eax, 36               ; Multiply by kernel size (3x3 = 9 elements, 4 bytes each)
    add eax, conv_out 
    call mem_alloc
    test eax, eax
    jz .alloc_error
    mov esi, eax               ; Save allocated pointer

    ; Read weights from binary file
    mov eax, conv_in           ; Input channels
    imul eax, conv_out         ; Multiply by output channels
    imul eax, 36               ; Multiply by kernel size (3x3 = 9 elements, 4 bytes each)
    mov ebx, esi
    call fio_read              ; Read weights

    ; Read biases from binary file
    mov eax, conv_out          ; Output channels
    imul eax, 4                ; Multiply by 4 bytes per channel
    add ebx, eax
    call fio_read              ; Read biases

    jmp .done

.alloc_error:
    ; Handle memory allocation error
    mov eax, error_alloc_msg
    call io_writestr

.done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret


parse_linear_params:
    ; Assumes ESI points to the line "Linear in=X out=Y"
    push ebx
    push ecx
    push edx

    ; Locate "in="
    mov edi, esi
.find_in:
    cmp byte [edi], 0         ; End of string?
    je .error                 ; If not found, error
    mov esi, edi
    mov edi, in_prefix        ; Target string ("in=")
    call compare_prefix
    test eax, eax             ; Check if match
    jnz .parse_in

    inc edi                   ; Move to next character
    jmp .find_in

.parse_in:
    add edi, 3                ; Move past "in="
    xor eax, eax              ; Clear eax
.parse_in_value:
    cmp byte [edi], '0'
    jb .in_done               ; If not a digit, done
    cmp byte [edi], '9'
    ja .in_done
    imul eax, eax, 10
    add al, [edi]             ; Add digit to eax
    sub al, '0'
    inc edi                   ; Move to next character
    jmp .parse_in_value

.in_done:
    mov [linear_in], eax

    ; Locate "out="
    mov edi, esi
.find_out:
    cmp byte [edi], 0         ; End of string?
    je .error                 ; If not found, error
    mov esi, edi
    mov edi, out_prefix       ; Target string ("out=")
    call compare_prefix
    test eax, eax
    jnz .parse_out
    inc edi                   ; Move to next character
    jmp .find_out

.parse_out:
    add edi, 4                ; Move past "out="
    xor eax, eax              ; Clear eax
.parse_out_value:
    cmp byte [edi], '0'
    jb .out_done              ; If not a digit, done
    cmp byte [edi], '9'
    ja .out_done
    imul eax, eax, 10         ; Multiply current value by 10
    add al, [edi]             ; Add digit to eax
    sub al, '0'
    inc edi
    jmp .parse_out_value

.out_done:
    mov [linear_out], eax     ; Store output size
    jmp .done

.error:
    mov eax, error_parse_msg
    call io_writestr

.done:
    pop edx                   ; Restore registers
    pop ecx
    pop ebx
    ret


; Parse Conv layer parameters
parse_conv_params:
    ; Assumes ESI points to the line "Conv in=X out=Y"
    push ebx                  ; Save registers
    push ecx
    push edx

    ; Locate "in="
    mov edi, esi              ; Start of the line
.find_in:
    cmp byte [edi], 0         ; End of string?
    je .error
    mov esi, edi              ; Input string (current position in line)
    mov edi, in_prefix       ; Target string ("out=")
    call compare_prefix
    test eax, eax
    jnz .parse_in

    inc edi
    jmp .find_in

.parse_in:
    add edi, 3                ; Move past "in="
    xor eax, eax              ; Clear eax
.parse_in_value:
    cmp byte [edi], '0'
    jb .in_done               ; If not a digit, done
    cmp byte [edi], '9'
    ja .in_done
    imul eax, eax, 10         ; Multiply current value by 10
    add al, [edi]             ; Add digit to eax
    sub al, '0'
    inc edi                   ; Move to next character
    jmp .parse_in_value

.in_done:
    mov [conv_in], eax

    ; Locate "out="
    mov edi, esi              ; Start of the line again
.find_out:
    cmp byte [edi], 0         ; End of string?
    je .error
    mov esi, edi              ; Input string (current position in line)
    mov edi, out_prefix       ; Target string ("out=")
    call compare_prefix
    test eax, eax             ; Check if match
    jnz .parse_out
    inc edi                   ; Move to next character
    jmp .find_out

.parse_out:
    add edi, 4                ; Move past "out="
    xor eax, eax              ; Clear eax
.parse_out_value:
    cmp byte [edi], '0'
    jb .out_done              ; If not a digit, done
    cmp byte [edi], '9'
    ja .out_done
    imul eax, eax, 10         ; Multiply current value by 10
    add al, [edi]             ; Add digit to eax
    sub al, '0'
    inc edi
    jmp .parse_out_value

.out_done:
    mov [conv_out], eax       ; Store output channels
    jmp .done

.error:
    mov eax, error_parse_msg  ; Error message for parsing failure
    call io_writestr

.done:
    pop edx
    pop ecx
    pop ebx
    ret

compare_conv_prefix:
    ; eax = pointer to line
    mov ebx, conv_prefix
    call compare_prefix
    ret

compare_linear_prefix:
    ; eax = pointer to line
    mov ebx, linear_prefix
    call compare_prefix
    ret

compare_relu_prefix:
    ; eax = pointer to line
    mov ebx, relu_prefix
    call compare_prefix
    ret

compare_argmax_prefix:
    ; eax = pointer to line
    mov ebx, argmax_prefix
    call compare_prefix
    ret

compare_maxpool_prefix:
    ; eax = pointer to line
    mov ebx, maxpool_prefix
    call compare_prefix
    ret

; Compare a string with a prefix
compare_prefix:
    ; eax = string pointer
    ; ebx = prefix pointer
    push ecx
    push edx
    xor ecx, ecx
.compare_loop:
    mov dl, [eax + ecx]
    mov dh, [ebx + ecx]
    cmp dl, 0
    je .done_compare
    cmp dh, 0
    je .done_compare
    cmp dl, dh
    jne .not_match
    inc ecx
    jmp .compare_loop
.done_compare:
    xor eax, eax
    ret
.not_match:
    mov eax, 1
    ret
; ----------------------------------------------------------------------------------------
; Optimized `Linear` Layer Implementation with SSE
linear_layer:
    ;   esi - Input vector pointer
    ;   edi - Output vector pointer
    ;   ebx - Weights pointer
    ;   ecx - Bias pointer

    push ebp                   ; Save registers
    push ebx
    push ecx
    push edx

    xor edx, edx               ; Output neuron counter

    ; For each output neuron
.linear_output:
    cmp edx, [linear_out]      ; Check number of output neurons
    jge .done_linear           ; Exit if all outputs are processed

    mov ecx, [linear_in]       ; Number of inputs
    xorps xmm0, xmm0           ; Clear accumulator (XMM0 for dot product)

    .dot_product:
        cmp ecx, 0             ; Check if done
        jle .apply_bias        ; If no more inputs, add bias

        movaps xmm1, [esi]     ; Load 4 inputs into XMM1
        movaps xmm2, [ebx]     ; Load 4 weights into XMM2
        mulps xmm1, xmm2       ; Multiply inputs by weights
        addps xmm0, xmm1       ; Accumulate results

        add esi, 16            ; Move to next 4 inputs
        add ebx, 16            ; Move to next 4 weights
        sub ecx, 4             ; Processed 4 inputs
        jmp .dot_product

    .apply_bias:
        movss xmm1, [ecx]      ; Load bias for the output neuron
        addss xmm0, xmm1       ; Add bias to the dot product
        movss [edi], xmm0      ; Store result in the output vector

        add edi, 4             ; Move to next output neuron
        inc edx                ; Increment output counter
        jmp .linear_output

.done_linear:
    pop edx                    ; Restore registers
    pop ecx
    pop ebx
    pop ebp
    ret


; ----------------------------------------------------------------------------------------
; ReLU Activation Layer Implementation
relu_layer:
    ; Arguments:
    ;   esi - Input vector pointer
    ;   edi - Output vector pointer
    ;   ecx - Number of elements

    xor edx, edx               ; Clear index counter

.relu_loop:
    cmp edx, ecx               ; Check if all elements are processed
    jge .done_relu             ; Exit if done

    movss xmm0, [esi + edx*4]  ; Load input value
    maxss xmm0, dword [zero]   ; ReLU: max(0, value)
    movss [edi + edx*4], xmm0  ; Store result

    inc edx                    ; Increment counter
    jmp .relu_loop

.done_relu:
    ret

;----------------------------------------------------------------------------------------
; ArgMax
argmax_layer:
    ; Arguments:
    ;   esi - Input vector pointer
    ;   ecx - Number of elements
    ;   eax - Result index (output)

    xor edi, edi               ; Initialize max index
    movss xmm0, dword [esi]    ; Initialize max value with the first element

    xor edx, edx               ; Clear counter
.argmax_loop:
    cmp edx, ecx               ; Check if all elements are processed
    jge .done_argmax

    movss xmm1, [esi + edx*4]  ; Load current value
    comiss xmm1, xmm0          ;Compare current value with max
    jbe .skip_update           ; If current <= max skip update

    movss xmm0, xmm1           ; New max value
    mov edi, edx               ; New max index

.skip_update:
    inc edx                    ; Increment counter
    jmp .argmax_loop

.done_argmax:
    mov eax, edi               ; eax = max index
    ret

;-----------------------------------------------------------------------------------------
conv_layer:
    ; Arguments:
    ;   esi - Input feature map pointer
    ;   edi - Output feature map pointer
    ;   ebx - Weights pointer
    ;   ecx - Bias pointer
    ;   edx - Input dimensions (width, height, channels)
    ;   eax - Output dimensions (width, height, channels)

    ret
;-----------------------------------------------------------------------------------------

draw_menu:
    ; Create the graphics window
    mov		eax, WIDTH		; window width (X)
	mov		ebx, HEIGHT		; window height (Y)
	mov		ecx, 0			; window mode
	mov		edx, caption	; window caption
	call	gfx_init

    test	eax, eax		; if the return value is 0, something went wrong
	jnz		.init
	mov		eax, errormsg
	call	io_writestr
	call	io_writeln
	ret

.init:
    mov		eax, infomsg
	call	io_writestr
	call	io_writeln

    ; Main loop for drawing the image
.mainloop:
    call    gfx_map         ; map the framebuffer -> EAX is the pointer

    ; Loop over the lines   
    xor     ecx, ecx        ; ECX - line (Y)
.yloop:
    cmp     ecx, 224
    jge     .draw_button1

    ; Loop over the columns
    xor     edx, edx        ; EDX - column (X)

.xloop:
    cmp     edx, WIDTH
    jge     .xend

    ; Write the pixel 
    
    xor     ebx, ebx
    mov     [eax], ebx

    add     eax, 4      ;next pixel

    inc     edx
    jmp     .xloop

.xend:
	inc		ecx
	jmp		.yloop

.draw_button1:
    .yloop_button1:
        cmp     ecx, 244
        jge     .draw_button2

        ; Loop over the columns
        xor     edx, edx        ; EDX - column (X)

    .xloop_button1:
        cmp     edx, WIDTH
        jge     .xend_button1

        xor     ebx, ebx
        add     ebx, 0x0000FF00 ; Red color for the button
        mov     [eax], ebx

        add     eax, 4          ; Next pixel

        inc     edx
        jmp     .xloop_button1

    .xend_button1:
        inc     ecx
        jmp     .yloop_button1


.draw_button2:
    .yloop_button2:
        cmp     ecx, 264
        jge     .yend

        ; Loop over the columns
        xor     edx, edx        ; EDX - column (X)

    .xloop_button2:
        cmp     edx, WIDTH
        jge     .xend_button2

        xor     ebx, ebx
        add     ebx, 0x00FF0000 ; Red color for the button
        mov     [eax], ebx

        add     eax, 4          ; Next pixel

        inc     edx
        jmp     .xloop_button2

    .xend_button2:
        inc     ecx
        jmp     .yloop_button2

.yend:
    call    gfx_unmap        ; Unmap the framebuffer
    call    gfx_draw         ; Draw the contents of the framebuffer
    ret

section .bss
    draw_zone resb 224 * 224 * 4  ; Reserve space for 224x224 pixels, 4 bytes per pixel
    resized_zone resb 28 * 28 * 4 ; Reserve space for 28x28 pixels, 4 bytes per pixel for the resized image
    structure_buffer resb 512       ; Buffer for reading structure file
    buffer_size equ 512             ; Buffer size for fio_read
    input_vector resd 10000
    output_vector resd 10000
    weights_pointer resd 1
    bias_pointer resd 1
    conv_in resd 1
    conv_out resd 1
    conv_count resd 1
    conv_size resd 1
    linear_in resd 1
    linear_out resd 1
    linear_count resd 1
    linear_size resd 1

section .data
    in_prefix db "in=", 0
    out_prefix db "out=", 0
    conv_prefix db "Conv", 0
    linear_prefix db "Linear", 0
    resize_prefix db "Resize", 0
    scale_prefix db "Scale", 0
    relu_prefix db "ReLU", 0
    argmax_prefix db "ArgMax", 0
    maxpool_prefix db "MaxPool", 0
    error_structure_msg db "Error opening structure file", 0
    error_weights_msg db "Error opening weights file", 0
    error_alloc_msg db "Memory allocation failed.", 0
    error_parse_msg db "Parsing error occurred.", 0
    kernel_size dd 0
    stride dd 0
    padding dd 0
    scaled_array times 784 dd 0.0         ; Array to store scaled [-1, 1] values
    ;linear_output times 1000 dd 0.0         ; Array to store the linear output
    one  dd 1.0                         ; Constant 1.0 for white pixels
    neg_one dd -1.0                     ; Constant -1.0 for black pixels
    zero dd 0.0                         ; Constant 0.0 for ReLU
    caption db "Assembly number recognizer", 0
	infomsg db "Draw a single digit number! [GREEN BUTTON] Detection [RED BUTTON] Exit ", 0
	errormsg db "ERROR: could not initialize graphics!", 0
    detectionmsg db "Detect function called!", 0
    lin_model_txt db "lin_model.txt", 0
    lin_model_bin db "lin_model.bin", 0
    mouse_x_msg db "Mouse X: ", 0
    mouse_y_msg db " Mouse Y: ", 0

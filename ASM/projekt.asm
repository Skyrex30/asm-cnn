; Compile:
; nasm -f win32 projekt.asm
; nlink projekt.obj -lio -lgfx -o projekt.exe

%include 'io.inc'
%include 'gfx.inc'

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
        shl ecx, 2                  ; Each pixel is 4 bytes
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
    call detect_number


    ret


; ----------------------------------------------------------------------------------------
; Function to store the drawing zone


store_drawing_zone:
    call gfx_map                 ; Map the framebuffer
    mov esi, eax                 ; ESI = framebuffer pointer (top-left pixel)
    mov edi, draw_zone          ; EDI = address of the drawing zone 
    xor ecx, ecx                 ; ECX = Y (row counter)

.store_rows:
    cmp ecx, 224                 ; Loop through each row
    jge .end_store               ; Stop if Y >= 224

    xor edx, edx                 ; EDX = X (column counter)

.store_columns:
    cmp edx, 224                 ; Loop through each column
    jge .next_row                ; Move to next row after 224 columns

    mov eax, [esi]               ; Get pixel value from the framebuffer
    mov [edi], eax               ; Store it in the draw_zone buffer

    add esi, 4                  ; Move to the next pixel in the framebuffer
    add edi, 4                   ; Move to the next position in the buffer

    inc edx                      ; Increment column counter
    jmp .store_columns

.next_row:
    inc ecx                      ; Increment row counter
    jmp .store_rows

.end_store:
    call gfx_unmap               ; Unmap the framebuffer
    ret
;----------------------------------------------------------------------------------------
; Function to resize the drawing zone to 28x28

resize_to_28x28:
    mov esi, draw_zone         ; ESI = pointer to the 224x224 source image
    mov edi, resized_zone      ; EDI = pointer to the 28x28 destination image
    
    mov ecx, 28                ; Outer loop counter for the rows (Y)
    xor ebx, ebx               ; EBX = Y coordinate in the 28x28 image

.outer_loop:
    push ecx                   ; Save the row counter

    mov edx, 28                ; Inner loop counter for the columns (X)
    xor eax, eax               ; EAX = X coordinate in the 28x28 image

.inner_loop:
    ; Calculate the corresponding X, Y in the original 224x224 image
    ; Scaling factor is 8, so:
    ;   original_x = X in 28x28 * 8
    ;   original_y = Y in 28x28 * 8

    mov ecx, ebx               
    imul ecx, 8                ; ECX = Y in 224x224 image (EBX * 8)

    mov edx, eax               
    imul edx, 8                ; EDX = X in 224x224 image (EAX * 8)

    ; Compute the memory offset in the original image buffer
    imul ecx, 224              
    add ecx, edx               ; ECX = (Y * 8) * 224 + (X * 8) (final pixel offset)
    shl ecx, 2                 ; Multiply by 4 (since each pixel is 4 bytes)
    add ecx, esi               ; ECX = address of the nearest pixel in 224x224

    ; Copy the pixel to the 28x28 buffer
    mov eax, [ecx]             ; Get the pixel from the original image
    mov [edi], eax             ; Store the pixel in the resized image

    ; Move to the next pixel in the destination buffer
    add edi, 4                 ; Move to the next pixel in the 28x28 buffer

    ; Increment X-coordinate (EAX) for the next pixel in 28x28 image
    inc eax                    ; Move to the next X-coordinate
    
    ; Loop over the columns
    dec edx                    ; Decrement the column counter
    jnz .inner_loop            ; Repeat for all columns

    ; Move to the next row in the destination image
    pop ecx                    ; Restore the row counter
    inc ebx                    ; Increment Y coordinate for 28x28
    dec ecx                    ; Decrement row counter
    jnz .outer_loop            ; Repeat for all rows

    ret
;----------------------------------------------------------------------------------------
; Function to scale the image to floats

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
; Function to detect a number

detect_number:
    mov esi, draw_zone           ; ESI = start of the draw_zone buffer
    xor ecx, ecx                 ; ECX = row counter 

.analyze_rows:
    cmp ecx, 224                 ; Analyze each row
    jge .end_detect              ; Stop after 224 rows

    xor edx, edx                 ; EDX = column counter

.analyze_columns:
    cmp edx, 224                 ; Analyze each column
    jge .next_row                ; Move to next row after 224 columns

    mov eax, [esi]               ; Get the pixel value from the buffer

    ; Analyze pixel here 

    add esi, 4                   ; Move to the next pixel in the buffer
    inc edx                      ; Increment column counter
    jmp .analyze_columns

.next_row:
    inc ecx                      ; Increment row counter
    jmp .analyze_rows

.end_detect:
    ret

;-----------------------------------------------------------------------------------------

draw_menu:
    ; Create the graphics window
    mov		eax, WIDTH		; window width (X)
	mov		ebx, HEIGHT		; window height (Y)
	mov		ecx, 0			; window mode (NOT fullscreen!)
	mov		edx, caption	; window caption
	call	gfx_init

    test	eax, eax		; if the return value is 0, something went wrong
	jnz		.init
	; Print error message and exit
	mov		eax, errormsg
	call	io_writestr
	call	io_writeln
	ret

.init:
    mov		eax, infomsg	; print some usage info
	call	io_writestr
	call	io_writeln

    ; Main loop for drawing the image
.mainloop:
    ; Draw something
    call    gfx_map         ; map the framebuffer -> EAX will contain the pointer

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
section .data
   scaled_array times 784 dd 0.0         ; Array to store scaled [-1, 1] values
    one  dd 1.0                         ; Constant 1.0 for white pixels
    neg_one dd -1.0                     ; Constant -1.0 for black pixels
    caption db "Assembly number recognizer", 0
	infomsg db "Draw a single digit number! [GREEN BUTTON] Detection [RED BUTTON] Exit ", 0
	errormsg db "ERROR: could not initialize graphics!", 0
    detectionmsg db "Detect function called!", 0
    mouse_x_msg db "Mouse X: ", 0
    mouse_y_msg db " Mouse Y: ", 0

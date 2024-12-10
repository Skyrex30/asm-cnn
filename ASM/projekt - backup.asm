; Compile:
; nasm -f win32 projekt.asm
; nlink projekt.obj -lio -lgfx -o projekt.exe

%include 'io.inc'
%include 'gfx.inc'

%define WIDTH  500
%define HEIGHT 500

%define BUTTON1_X 100        ; X-coordinate of the first button's top-left corner
%define BUTTON1_Y 100        ; Y-coordinate of the first button's top-left corner
%define BUTTON2_X 300        ; X-coordinate of the second button's top-left corner
%define BUTTON2_Y 100        ; Y-coordinate of the second button's top-left corner
%define BUTTON_WIDTH 100     ; Width of the buttons
%define BUTTON_HEIGHT 50    ; Height of the buttons

global main

section .text
main:
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
    push    eax

    ; Loop over the lines   
    xor     ecx, ecx        ; ECX - line (Y)
.yloop:
    cmp     ecx, HEIGHT
    jge     .yend

    ; Loop over the columns
    xor     edx, edx        ; EDX - column (X)

.xloop:
    cmp     edx, WIDTH
    jge     .xend

    ; Write the pixel (we have to initialize each colors value)
    ; blue
    xor     ebx, ebx
    mov     [eax], bl
    ; green
    xor     ebx, ebx
    mov     [eax+1], bl
    ; red
    xor     ebx, ebx
    mov     [eax+2], bl
    ; zero
    xor     ebx, ebx
    mov     [eax+3], bl

    add     eax, 4      ;next pixel

    inc     edx
    jmp     .xloop

.xend:
	inc		ecx
	jmp		.yloop

.yend:
    pop     eax
    mov     ecx, BUTTON1_X        ; X position of Button 1
    mov     edx, BUTTON1_Y        ; Y position of Button 1
    mov     ebx, BUTTON_WIDTH     ; Button width
    mov     esi, BUTTON_HEIGHT    ; Button height
    mov     edi, 0x0000FF00       ; Green color (0x00GGRRBB format)
    call    draw_button           ; Draw Button 1

    mov     ecx, BUTTON2_X        ; X position of Button 2
    mov     edx, BUTTON2_Y        ; Y position of Button 2
    mov     ebx, BUTTON_WIDTH     ; Button width
    mov     esi, BUTTON_HEIGHT    ; Button height
    mov     edi, 0x000000FF       ; Red color
    call    draw_button           ; Draw Button 2

    
	call	gfx_unmap		; unmap the framebuffer
	call	gfx_draw		; draw the contents of the framebuffer (*must* be called once in each iteration!)
	


draw_button:
    ; Draw a rectangle (button) at a given position with a specific color
    ; Input:
    ;   EAX = framebuffer pointer
    ;   ECX = x-coordinate of the top-left corner
    ;   EDX = y-coordinate of the top-left corner
    ;   EBX = button width
    ;   ESI = button height
    ;   EDI = color (0x00RRGGBB)

    push    esi
    push    edi
    push    ebp

    ; Calculate the starting position in the framebuffer
    imul    edx, WIDTH            ; EDX = Y * WIDTH
    add     edx, ecx              ; EDX = Y * WIDTH + X
    imul    edx, 4              ; EDX = (Y * WIDTH + X) * 4 (each pixel is 4 bytes)
    add     eax, edx              ; EAX = framebuffer pointer + offset
    xor     ecx, ecx
    mov     ecx, eax              ; store the starting address in EBP

    mov     eax, edi              ; load the color

    ; Outer loop: for each row in the rectangle
.draw_button_outer_loop:
    mov     edi, ebx              ; set the column counter (button width)
.draw_button_inner_loop:
    mov     [ecx], eax            ; set the pixel color
    call	gfx_unmap		; unmap the framebuffer
	call	gfx_draw
    push    eax
    call    gfx_map
    pop     eax
    add     ecx, 4                ; move to the next pixel (4 bytes per pixel)
    dec     edi
    jnz     .draw_button_inner_loop
    
    push    ebx                   ; Save button width
    shl     ebx, 2                ; EBX = EBX * 4 (to calculate byte offset)
    sub     ecx, ebx              ; go back to the beginning of the row
    pop     ebx                   ; Restore button width
    add     ecx, WIDTH*4          ; move to the next row (advance to the next line in the framebuffer)
    dec     esi
    jnz     .draw_button_outer_loop

    pop     ebp
    pop     edi
    pop     esi
    ret



;.end:
;   call	gfx_destroy
;   ret


section .data
    caption db "Assembly number recognizer", 0
	infomsg db "Draw a single digit number!", 0
	errormsg db "ERROR: could not initialize graphics!", 0
	
	; These are used for moving the image
	offsetx dd 0
	offsety dd 0

	;; Crossword puzzle bootloader

bits 16
org 0x7c00
cpu 8086

;; changed by prebuild.py to load puzzle data as immediates 
puz_len:    equ 232
width:      equ 4
height:     equ 4

;; other immediates
col_width:	equ 25
indent:		equ 4

	
puz_off:	equ 0x7c00
across_msg:	equ puz_off + 0x2 	; In .puz specification
down_msg:	equ puz_off + 0x9
solution:	equ puz_off + 0x34
grid:		equ puz_off + 0x34 + (width*height)

	;; no longer needed - using these as immediates
	;; puz_width:	equ puz_off + 0x2c
	;; puz_height:	equ puz_off + 0x2d

	;; Not in .puz specification: used as storage saved over those dumb checksums
next_aloc:	equ puz_off + 0x10
next_dloc:	equ puz_off + 0x12
next_clue:	equ puz_off + 0x14
cur_clue:	equ puz_off + 0x16	; the current clue number when initializing
	
start:
	mov ax, 0x0002				; Set Video mode 80x25 with color
	int 0x10					
	
	mov ax, 0xb800				; Load text video segment
	mov es, ax					; in ES for stosw instructions using DI

	call init_clues
	
print_puzzle:
	
	xor ax, ax					; Zero out AX and DI 
	xor bx, bx					; 
	xor cx, cx					; 
	xor dx, dx					; dl is x value, dh is y value

	xor di, di					; ES:DI points to beginning of video memory
	
p1:	call print_line_row			; print the row with lines (e.g. +-+-+-+)
	call print_text_row			; prints the row with text (e.g. | | | |)

	xor dl, dl
	inc dh
	cmp dh, height				; check if end of crossword
	jnz p1
	
	call print_line_row
	
	jmp main

print_line_row:
	mov byte cl, width
p2:	call handle_clue
	stosw
	mov ax, 0x0f2d
	stosw
	
	inc dl
	cmp dl, width
	jz p3

	jmp p2
	
p3:	mov ax, 0x0f2b				; adds the final "+" and then goes to the next
	stosw						; line, calculated using 2 bytes per char and
	add di, 0xa0-(4*width+2)	; 2 chars per cell with the extra +
	ret

	
print_text_row:
	mov cx, width+1
	;; lodsb 						; load byte of solution from DS:SI to AL
p4:	mov ax, 0x0f7c
	stosw
	mov ax, 0x0f20				; White on black background color
	stosw						; store AX in ES:DI
	loop p4						; loop it
	
	add di, 0xa0-(4*width+4)	; next line
	ret

	;; main logic function for printing clues and numbering cells correctly
	;; bx must be preserved - has (y,x) cords
	;;
	;; fuck so ax is not a valid memory location. need to use bx to point to grid
	;; cx for current grid loc
	;; and dx for clue number? or dx for grid loc and clue number in memory?
handle_clue:
	xor bx, bx 					; if the current position is a black square '.'
	mov ax, width	  			; (a '.' or 0x2e in the grid), then return a '+'
	mul dh
	add al, dl
	add ax, grid
	mov bx, ax
	cmp byte [bx], 0x2e
	je	h5
	xor ax, ax
	
	;; if dl=0 or the cell to the left is '.', handle across clue
	cmp dh, height				; if its the last row, don't handle across clue
	je h2
	dec bx						; ax is pointing at the current grid location
	cmp dl, 0					; so a simple dec bx should check the cell to the left
	je h1						
	cmp byte [bx], 0x2e
	jne h2

h1:	call handle_aclue
	mov al, 1
	
	;; if dh=0 or the cell above is '.', handle down clue
h2:	cmp dh, 0
	je 	h3
	sub bx, width+1				; check the above row
	cmp byte [bx], 0x2e				; accounting for previous dec
	jne h4
	
h3:	call handle_dclue
	mov al, 1

h4:	cmp al, 1					; dh contains whether a clue number exists
	jne h5						; in this cell. If not, return just a "+"
	
	mov word bx, [cur_clue]		; return and increment a printable clue number
	mov ax, bx
	inc bl				 		; note: only works for clue numbers less than 10
	mov word [cur_clue], bx
	ret
	
h5:	mov ax, 0x0F2B				; return a simple "+" for the cross
	ret

handle_aclue:
	ret
	
handle_dclue:	
	ret
	
	
init_clues:	
	mov di, (col_width+indent)*2 ; print ACROSS at the top of col 2
	mov si, across_msg
	mov cl, 6
i1: lodsb
	mov ah, 0x0f
	stosw
	loop i1

	mov word [next_aloc], 0xa0+col_width*2 ; next across clue goes under ACROSS
	
	mov di, col_width*4 + indent*2 ;print DOWN at the top of col 3
	mov si, down_msg
	mov cl, 4
i2:	lodsb
	mov ah, 0x0f
	stosw
	loop i2

	mov word [next_dloc], 0xa0+col_width*4 ; next down clue goes right under DOWNx
	
	mov word [cur_clue], 0x0f31
	ret

	
main:							; main loop
	jmp main

	
	;; Pad the rest of the file with null bytes and add
	;; 0x55AA to the end to make the puzzle and code bootable 
times (510-puz_len)-($-$$) db 0
dw 0xAA55

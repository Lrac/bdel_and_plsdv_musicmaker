#VGA program

.equ ADDR_VGA, 0x08000000
.equ ADDR_CHAR, 0x09000000
.include "nios_macros.s"
.global VGA

VGA:
	SAVE_REG:
		subi sp, sp, 32
		stw r16, 24(sp)
		stw r17, 20(sp)
		stw r18, 16(sp)
		stw r19, 12(sp)
		stw r20, 8(sp)
		stw r21, 4(sp)
		stw r22, 0(sp)
		stw ra, 28(sp)
		
		
	movia r16, ADDR_VGA
	movia r17, ADDR_CHAR
	movui r18,0x0000  /* BLACK pixel */
#######################################################DO NOT TOUCH R16 AND R17 IF THERE ARE ENOUGH REG##################################################
	
CLEARSCREEN:
	movi r19, 319	# r8 = x
	movi r20, 239	# r9 = y
	LOOP:
		blt r19, r0, DONE_LOOP
		LOOPY:
			blt r20, r0, DECX
			DRAWPIXEL:
				muli r21, r19, 2		#multiply x by 2
				muli r22, r20, 1024		#multiply y by 1024
				add r21, r21, r22		#get the number for memory
				add r22, r16, r21	
				sthio r18, 0(r22)		#draw a black dot
				subi r20, r20, 1		#decrement y value by 1
				br LOOPY
		DECX:
			subi r19, r19, 1			#decrement x value by 1 once the y value reaches 0
			movi r20, 239				#re-assign x to start from the very right of the page
			br LOOP
DONE_LOOP:
	call DRAW_MODE
	call DRAW_TIME
	br VGA_EPILG
	
DRAW_MODE:
	movia r19, mode
	ldb r19, 0(r19)			#r19 contains slider info

	andi r20, r19, 0b1			
	bne r20, r0, MODE_REC
	
	andi r20, r19, 0b10
	bne r20, r0, MODE_PLAY
	
	andi r20, r19, 0b100
	bne r20, r0, MODE_SPEED_UP
	
	andi r20, r19, 0b1000
	bne r20, r0, MODE_SLOW_DOWN
	
	#else, W for waiting
	MODE_WAIT:
		movi r19, 0x57
		br PRINT_MODE
	MODE_SLOW_DOWN:
		movi r19, 0x44
		br PRINT_MODE
	MODE_REC:
		movi r19, 0x52
		br PRINT_MODE
	MODE_PLAY:
		movi r19, 0x50
		br PRINT_MODE
	MODE_SPEED_UP:
		movi r19, 0x55
		br PRINT_MODE

	PRINT_MODE:
		stbio r19, 260(r17) 					#prints out the mode letter
	
	PRINT_TEXT:							#prints out "mode: "
		movi r19, 0x4D
		stbio r19, 132(r17) 			
		movi r19, 0x6F
		stbio r19, 133(r17) 
		movi r19, 0x64
		stbio r19, 134(r17)
		movi r19, 0x65
		stbio r19, 135(r17)
		movi r19, 0x3A
		stbio r19, 136(r17)
		ret

DRAW_TIME:
	movia r18, TIME_TRACE
	ldw r19, 0(TIME_TRACE)	#http://stackoverflow.com/questions/5189631/how-can-i-take-mod-of-a-number-in-assembly-in-motorola-m6800/5189800#5189800 (try this later)
	GET_LAST_NUMBER:
		mov r18, 10					#divide the time stored by 10 until the number is less than 10 to get the reminder
		subi r19, r19, r18
		bge r19, r18, GET_LAST_NUMBER

		ldw r20, 0(TIME_TRACE)				#get the time stored and subtract it by the last bit we have just found
		sub r20, r20, r19
	GET_MIDDLE_NUMBER:
		mov r18, 100					#divide this number by 100 until the number is less than 100 to get the reminder
		subi r20, r20, r18
		bge r20, r18, GET_MIDDLE_NUMBER
	
	GET_SECOND:
		ldw r21, 0(TIME_TRACE)				#get the time stored again and subtract it by the last bit and middle bit *10
		add r18, r18, r19
		sub r21, r21, r18				#now r19 stores the lowest number, r20 stores the middle number and r21 stores the second
		
	CONVERT_TO_ASCII:
		addi r19, r19, 0x37
		mov r18, r18, 10
		div r20, r20, r18
		addi r20, r20, 0x37
		mov r18, r18, 100
		div r21, r21, 100
		addi r21, r21, 0x37
		movi r22, 0x3A					#r22 contains character for ':'
	PRINT_TIME:
		stbio r19, 391(r17)
		stbio r20, 390(r17)
		stbio r22, 389(r17)
		stbio r21, 388(r17)
	
	movi r19, 5	
	blt r21, r19, DONE_DRAW_TEXT				#if second = 5, reset time	
	movia r19, TIME_TRACE
	stw r0, 0(r19)

	DONE_DRAW_TEXT:
		ret
		

 
VGA_EPILG:
	ldw r16, 24(sp)
	ldw r17, 20(sp)
	ldw r18, 16(sp)
	ldw r19, 12(sp)
	ldw r20, 8(sp)
	ldw r21, 4(sp)
	ldw r22, 0(sp)
	ldw ra, 28(sp)
	addi sp, sp, 32
	ret

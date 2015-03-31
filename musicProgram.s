.equ ADDR_AUDIODACFIFO, 0x10003040
.equ ADDR_SWITCHES, 0x10000040
.equ ADDR_TIMER, 0x10002000
.equ ADDR_LEDR, 0x10000000
.equ SONG_LENGTH, 0x35B60
.equ SP_START, 0x007FFFFC
.equ PERIOD, 500000				#period to be every .1 s since 50000000 is not divisible by 60
.equ PS2CONTROLLER, 0x10000100
.equ ADDR_VGA, 0x08000000
.equ ADDR_CHAR, 0x09000000
.equ KB_R, 0x2D
.equ KB_ENT, 0x5A
.equ KB_SPACE, 0x29
.equ KB_RIGHT, 0x74
.equ KB_LEFT, 0x6B
.equ KB_E, 0x24

.include "nios_macros.s"
.global main
.global mode
.global TIME_TRACE

.section .data

mode:
	.skip 1
input_from_keyboard:
	.skip 1
	
.align 1
songone:
	.skip 0x35B60
TIME_TRACE:
	.skip 2

.align 2
recordindex:
	.skip 4

playindex:
	.skip 4	


	
	
.section .exceptions, "ax"
IHANDLER:
	addi sp, sp, -24
	stw et, 0(sp)
	rdctl et, ctl1
	stw et, 4(sp)
	stw ea, 8(sp)

	rdctl et, ctl4				#if 100 is on for ctl4, keyboard is prioritized before audio
	andi et, et, 0x10000000			#check IRQ7
	bne et, r0, HANDLE_PS2		
	
	rdctl et, ctl4
	andi et, et, 0b1000000
	bne et, r0, HANDLE_AUDIO	

	rdctl et, ctl4				#if timer interrupt *********** set priority later
	andi et, et, 0x1
	bne et, r0, HANDLE_TIMER	

	
	br EXIT_HANDLER
	
HANDLE_PS2:
	subi sp, sp, 20				#store values
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)
	stw r11, 12(sp)
	stw ra, 16(sp)
	movia r8, PS2CONTROLLER
	
	ldb r9, 4(r8)
	andi r9, 0b100000000			#check the 8th bit for interrupt
	beq r9, r0, DONE_PS2			#if the pending is low, go to DONE_PS2

PS2INTERRUPTS:
	#read the scan code stored in bit 0 to 7
	#note r8 now contains the base address
	ldb r9, 0(r8)
	andi r9, r9, 0x000f			# get the lower 8 bits for the data
	movia r11, input_from_kb
	
	/* compare to see what the letter is -> right now we have record(r), play/restart(enter), pause(space), [potential]continue(pause), 
	speed up(right arrow or 6 on number pad), slow down (left arrow or 4 on number pad)
	R 2D - 0b1
	Enter 5A - 0b010
	Space 29 - 0b011 (pause)
		 - 0b100 (play)
	Right arrow 74 - 0b110
	Left arrow 6B - 0b1010
	ECHO 24 - 0b0*/

	#check record
	movi r10, KB_R
	bne r10, r9, INPUT_NOT_R
	
	movi r8, 0b1
	stb r8, 0(r11)		
	br DONE_PS2

INPUT_NOT_R:
	#check play
	movi r10, KB_ENT
	bne r10, r9, INPUT_NOT_P
	
	movi r8, 0b010
	stb r8, 0(r11)		
	br DONE_PS2

INPUT_NOT_P:
	#check slow down
	movi r10, KB_LEFT
	bne r10, r9, INPUT_NOT_HT

	movi r8, 0b1010
	stb r8, 0(r11)		
	br DONE_PS2

INPUT_NOT_HT
	#check if speed up
	movi r10, KB_RIGHT
	bne r10, r9, INPUT_NOT_2T

	movi r8, 0b110
	stb r8, 0(r11)
	br DONE_PS2

INPUT_NOT_2T:
	#if input is eccho
	movi r10, KB_E
	bne r10, r9, EXIT_PS2

	stb r0, 0(r11)
	br DONE_PS2

DONE_PS2:
	#reset the time when change mode
	movia r8, time_trace	
	stb r0, 0(r8)

EXIT_PS2:
	ldw ra, 16(sp)
	ldw r11, 12(sp)
	ldw r10, 9(sp)
	ldw r9, 4(sp)
	ldw r8, 0(sp)
	addi sp, sp, 20				#restore all values
	br EXIT_HANDLER


HANDLE_TIMER:
	subi sp, sp, 16				#store values
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)
	stw ra, 12(sp)
	movia r8, ADDR_TIMER
	
	ldwio r9, 0(r8)				#set timeout bit to 0 and continue
	movia r10, 0xFFFFFFFE
	and r9, r9, r10
	stwio r9, 0(r8)
	
	movia r8, TIME_TRACE
	ldh r10, 0(r8)
	addi r10, r10, 1
	sth r10, 0(r8)
	call CHANGE_TIME

DONE_TIMER:	
	ldw ra, 12(sp)
	ldw r10, 9(sp)
	ldw r9, 4(sp)
	ldw r8, 0(sp)
	addi sp, sp, 16				#restore all values
	br EXIT_HANDLER

HANDLE_AUDIO:	
	movia et, ADDR_AUDIODACFIFO
	ldwio et, 0(et)
	andi et, et, 0x100
	bne et, r0, AUDIO_RECORD
	/*movia et, ADDR_AUDIODACFIFO
	ldwio et, 0(et)
	andi et, et, 0x200
	bne et, r0, AUDIO_PLAY*/	
	br EXIT_HANDLER
	
AUDIO_RECORD:
	subi sp, sp, 20
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)	
	stw r7, 12(sp)
	stw ra, 16(sp)
	
	movia r8, recordindex		#grab current recording index
	ldwio et, 0(r8)
	
	movia r8, ADDR_AUDIODACFIFO
	movia r9, songone
	
	srli et, et, 1
	muli et, et, 2				#move song pointers to correct index
	add r9, r9, et

	
	ldwio et, 8(r8)				#load audio values into memory
	ldwio et, 12(r8)
	mov r7, et
	call LED
	
	srli et, et, 16
	sth et, 0(r9)
	
	movia r8, recordindex		#increment recording index
	ldwio et, 0(r8)
	addi et, et, 1
	stwio et, 0(r8)
	
	ldw r8, 0(sp)
	ldw r9, 4(sp)
	ldw r10, 8(sp)
	ldw r7, 12(sp)
	ldw ra, 16(sp)
	addi sp, sp, 20
	br EXIT_HANDLER
	
	
/*AUDIO_PLAY:
	stw r8, 12(sp)
	stw r9, 16(sp)
	stw r10, 20(sp)
	
	movia r8, playindex
	ldwio et, 0(r8)
	
	movia r8, ADDR_AUDIODACFIFO
	movia r9, songone
	
	muli et, et, 2				#move song pointers to correct index
	add r9, r9, et
	add r10, r10, et
	
	ldw et, 0(r9)
	stwio et, 8(r8)
	ldw et, 0(r10)
	stwio et, 12(r8)
	
	movia r8, playindex		#increment play index
	ldwio et, 0(r8)
	addi et, et, 1
	stwio et, 0(r8)
	
	ldw r8, 12(sp)
	ldw r9, 16(sp)
	ldw r10, 20(sp)
	br EXIT_HANDLER
*/	
	
EXIT_HANDLER:
	ldw et, 4(sp)
	wrctl ctl1, et
	ldw et, 0(sp)
	ldw ea, 8(sp)
	addi sp, sp, 24
	addi ea, ea, -4
	eret


########################################################## MAIN ##########################################################

.section .text	
main:
	movia sp, SP_START
	
	movia r8, ADDR_TIMER	
	movui r9, %lo(PERIOD)
	stwio r9, 8(r8)
	movui r9, %hi(PERIOD)
	stwio r9, 12(r8)
	stwio r0, 0(r8)
	
	movi r9, 0b111
	stwio r9, 4(r8)

	movia r8, PS2CONTROLLER		#enable interrupt for PS/2
	ldw r9, 4(r8)
	ori r9, 0x1
	stw r9, 4(r8)

	movi r9, 0b10000001
	wrctl ctl3, r9
	movi r9, 0b1
	wrctl ctl0, r9

	#enable VGA
	movia r8, mode
	movi r9, r0
	stb r9, 0(r8)
	call VGA
		

MAINLOOP:
	movia r2, input_from_kb
	ldbio r3, 0(r2)
	movia r8, mode
	stb r3, 0(r8)

	call CHANGE_MODE 
	andi r3, r3, 0b1
	beq r3, r0, NOTRECORD
	
	#reset TIME_TRACE to 0 then call record
	#movia r8, TIME_TRACE
	#sth r0, 0(r8)
	call RECORD

	br MAINLOOP

NOTRECORD:
	ldbio r3, 0(r2)
	andi r3, r3, 0b10
	
	beq r3, r0, NOTPLAY
	ldbio r3, 0(r2)
	andi r3, r3, 0b10000
	mov r4, r0
	mov r5, r0
	beq r3, r0, nopitch
	movi r5, 1
	movi r4, -1
nopitch:
	#set TIME_TRACE to 0 and play
	#movia r8, TIME_TRACE
	#sth r0, 0(r8)
	call PLAY
	br MAINLOOP
NOTPLAY:
	/*ldbio r3, 0(r2)
	andi r3, r3, 0b100
	beq r3, r0, NOT2X
	movi r4, 1
	call PLAY
	br MAINLOOP
NOT2X:
	ldbio r3, 0(r2)
	andi r3, r3, 0b1000
	beq r3, r0, NOTHALFX
	movi r4, -1
	call PLAY
	br MAINLOOP
NOTHALFX:	*/
	call ECHO
	br MAINLOOP

RECORD:
	addi sp, sp, -4
	stw ra, 0(sp)

	wrctl ctl0, r0			#disable external interrupts while changing settings
	
	movia r8, ADDR_AUDIODACFIFO			#enable audio codec for read interrupts
	movi r9, 0b1
	stwio r9, 0(r8)
	
	movi r9, 0b11000001		#enable IRQ6 for audio codec, IRQ 7 for PS/2 and IRQ1 for timer
	wrctl ctl3, r9
	
	movi r9, 0b1				#enable external interrupts
	wrctl ctl0, r9
	
	movia r9, recordindex
	stw r0, 0(r9)
	movia r11, input_from_kb
	movia r12, SONG_LENGTH
	movi r13, 1
	movi r14, 0
	RECORDLOOP:	

		ldbio r10, 0(r11)			#check if they switch it off
		bne r10, r13, STOPRECORD
		ldw r10, 0(r9)				#check if we've reached max record length
		bge r10, r12, RESETINDEX
		br RECORDLOOP
	RESETINDEX:
		movi r14, 0b1
		stw r0, 0(r9)
		br RECORDLOOP
		
	STOPRECORD:
		movia r10, playindex
		stw r0, 0(r10)
		beq r14, r0, INDEX_UPDATED
		ldw r11, 0(r9)
		stw r11, 0(r10)
	INDEX_UPDATED:
		#disable interrupts
		wrctl ctl0, r0
		stwio r0, 0(r8)
		movi r8, 0b1
		wrctl ctl3, r8
		wrctl ctl0, r8
		
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
	
PLAY:
	addi sp, sp, -4
	stw ra, 0(sp)
	#movia r8, ADDR_AUDIODACFIFO			#enable audio codec for read interrupts
	#movi r12, 0b1000
	#stw r12, 0(r8)
	#stw r0, 0(r8)
	movia r15, input_from_kb
	movia r10, SONG_LENGTH
	movia r11, playindex
	movi r14, 0x10				#r14 is because currMode (default 1x speed)
	
PLAYLOOP:
	movia r2, input_from_kb
	ldb r3, 0(r2)					#r3 contains the slider switch info
	andi r3, r3, 0x10			#check is play bit is still high
	beq r3, r0, STOPPLAY

	ldw r12, 0(r11)					#r12 holds the playindex
	ldb r3, 0(r2)					#r3 contains the slider switch info
	beq r14, r3, SAMEMODE
		movia r24, mode
		stb r3, 0(r24)
		call CHANGE_MODE

		andi r9, r14, 0x10			#because it's possible that we change modes in the middle of playing, we need a way to properly set the playindex
		bne r9, r0, CHECK_SIDES		#.... yeah, have fun reading this violet ^_^
		
		andi r9, r14, 0x100
		bne r9, r0, SLOWED
		br SPED_UP
	CHECK_SIDES:
		andi r9, r3, 0x100
		bne r9, r0, SPEEDONCE
		br SLOWONCE
	SLOWED:
		slli r12, r12, 1
		andi r9, r3, 0x1000
		bne r9, r0, SLOWONCE
		br MODECHANGED
	SPED_UP:
		srli r12, r12, 1
		andi r9, r3, 0x100
		bne r9, r0, SPEEDONCE
		br MODECHANGED
	SLOWONCE:
		slli r12, r12, 1
		br MODECHANGED
	SPEEDONCE:
		srli r12, r12, 1
		br MODECHANGED
	MODECHANGED:
		stw r12, 0(r11)
		mov r14, r3				#update currMode
	
SAMEMODE:	
	ldb r3, 0(r2)
	andi r3, r3, 0x100 			#check for speedup
	bne r3, r0, SPEEDUP
	
	ldb r3, 0(r2)
	andi r3, r3, 0x1000
	bne r3, r0, SLOWDOWN
	br CHECKINDEX

SLOWDOWN
	srli r12, r12, 1
	br CHECKINDEX
SPEEDUP:
	slli r12, r12, 1
	br CHECKINDEX

CHECKINDEX:
	blt r12, r10, INDEXSET		#song plays on repeat
	stw r0, 0(r11)
	
INDEXSET:
	ldwio r9,4(r8)      # Read fifospace register 
	srli r9, r9, 16    # Extract # of spaces available in Output Channel FIFO 
	andi r20, r9, 0xff
	beq r20, r0, PLAYLOOP # If no samples in FIFO, go back to start 
	andi r20, r9, 0xff00
	beq r20, r0, PLAYLOOP

	movia r13, songone
	add r13, r13, r12

	
	ldh r16, 0(r13)				#load from songone
	slli r16, r16, 16
	stwio r16, 8(r8)
	stwio r16, 12(r8)
	
	mov r7, r16
	call LED
	
	ldw r12, 0(r11)	
	addi r12, r12, 1
	stw r12, 0(r11)
	br PLAYLOOP 
	
STOPPLAY:
	stwio r0, 0(r8)
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
	

ECHO:
	subi sp, sp, 4
	stw ra, 0(sp)
	movia r2,ADDR_AUDIODACFIFO
	ldwio r3,4(r2)      /* Read fifospace register */
	andi  r3,r3,0xff    /* Extract # of samples in Input Right Channel FIFO */
	beq   r3,r0,ECHODONE  /* If no samples in FIFO, go back to start */

	ldwio r3,8(r2)
	stwio r3,8(r2)      /* Echo to left channel */

	ldwio r3,12(r2)
	stwio r3,12(r2)  /* Echo to right channel */
	#mov r7, r3
	call LED
 ECHODONE:
	ldw ra, 0(sp)
	addi sp, sp, 4
	ret

	
LED:
	subi sp, sp, 32
	stw r16, 0(sp)
	stw r17, 4(sp)
	
	movia r16, ADDR_LEDR
	bge r7, r0, POSITIVE
	muli r7, r7, -1

POSITIVE:
	srli r7, r7, 16
	movi r17, 0
CHECK_AMP:
	bge r17, r7, DISPLAY_AMP
	slli r17, r17, 1
	addi r17, r17, 1
	br CHECK_AMP
DISPLAY_AMP:	
	stwio r17, 0(r16)
	ldw r17, 4(sp)
	ldw r16, 0(sp)
	addi sp, sp, 32
	ret


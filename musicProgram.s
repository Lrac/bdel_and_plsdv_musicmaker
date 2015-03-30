.equ ADDR_AUDIODACFIFO, 0x10003040
.equ ADDR_SWITCHES, 0x10000040
.equ ADDR_TIMER, 0x10002000
.equ SONG_LENGTH, 0x35B60
.equ SP_START, 0x007FFFFC
.equ PERIOD, 500000				#period to be every .1 s since 50000000 is not divisible by 60
.equ PS2CONTROLLER 0x10000100
.equ TIME_TRACE 0x0				#set to 0 at the beginning of every operation
.equ INPUT_FROM_KB 0x0

.include "nios_macros.s"
.global main
.global mode
.global TIME_TRACE

.section .data

.align 1
songone:
	.skip 0x35B60

.align 2
recordindex:
	.skip 4

playindex:
	.skip 4	

mode:
	.skip 1
	
.section .exceptions, "ax"
IHANDLER:
	addi sp, sp, -24
	stw et, 0(sp)
	rdctl et, ctl1
	stw et, 4(sp)
	stw ea, 8(sp)

	rdctl et, ctl4				#if 100 is on for ctl4, keyboard is priorized before audio
	andi et, et, 0x10000000			#check IRQ7
	bne et, r0, HANDLE_PS2

	rdctl et, ctl4				#if timer interrupt *********** set priority later
	andi et, et, 0x1
	bne et, r0, HANDLE_TIMER
	
	rdctl et, ctl4
	andi et, et, 0b1000000
	bne et, r0, HANDLE_AUDIO			
	
	br EXIT_HANDLER
	
HANDLE_PS2:######### remeber to set time to 0 when changing mode #####################
	subi sp, sp, 20				#store values
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)
	stw r11, 12(sp)
	stw ra, 16(sp)
	movia r8, PS2CONTROLLER
	
	ldw r9, 4(r8)
	andi r9, 0b100000000			#check the 8th bit for interrupt
	beq r9, r0, DONE_PS2			#if the pending is low, go to DONE_PS2

PS2INTERRUPTS:
	#read the scan code stored in bit 0 to 7
	#note r8 now contains the base address
	ldw r9, 0(r8)
	andi r9, r9, 0x000f			# get the lower 8 bits for the data
	andi r10, r10, 0x00f0
	srli r10, 0x4				# r9 contains the lower number and r10 contains the first number
	
	/* compare to see what the letter is -> right now we have record(r), play/restart(enter), pause(space), [potential]continue(pause), 
	speed up(right arrow or 6 on number pad), slow down (left arrow or 4 on number pad)
	R 2D - 0b001
	Enter 5A - 0b010
	Space 29 - 0b011 (pause)
		 - 0b100 (play)
	Right arrow 74 - 0b101
	Left arrow 6B - 0b110
	ECHO 24 - 000*/

	#check record
	movi r11, 0xD
	bne r11, r9, INPUT_NOT_R
	movi r11, 0x2
	bne r11, r10, INPUTNOT_R
	
	movia r11, INPUT_FROM_KB
	movi r8, 0b001
	stw r8, 0(r11)		
	br DONE_PS2

INPUT_NOT_R:
	#check play
	movi r11, 0xA
	bne r11, r9, INPUT_NOT_P
	movi r11, 0x2
	bne r11, r10, INPUTNOT_P

	movia r11, INPUT_FROM_KB
	movi r8, 0b010
	stw r8, 0(r11)		
	br DONE_PS2

INPUT_NOT_P:
	#check play
	movi r11, 0xA
	bne r11, r9, INPUT_NOT_P
	movi r11, 0x2
	bne r11, r10, INPUTNOT_P

	movia r11, INPUT_FROM_KB
	movi r8, 0b010
	stw r8, 0(r11)		
	br DONE_PS2
	
		



DONE_PS2:
	ldw ra, 16(sp)
	ldw r11, 12(sp)
	ldw r10, 9(sp)
	ldw r9, 4(sp)
	ldw r8, 0(sp)
	addi sp, sp, 16				#restore all values
	br EXIT_HANDLER




HANDLE_TIMER:
	subi sp, sp, 16				#store values
	stw r8, 0(sp)
	stw r9, 4(sp)
	stw r10, 8(sp)
	stw ra, 12(sp)
	movia r8, TIMER
	
	ldwio r9, 0(r8)				#set timeout bit to 0 and continue
	movia r10, 0xFFFFFFFE
	and r9, r9, r10
	stwio r9, 0(r8)
	
	movia r8, TIME_TRACER
	ldw r10, 0(r8)
	addi r10, r10, 1
	stw r10, 0(r8)
	call VGA

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
	movia et, ADDR_AUDIODACFIFO
	ldwio et, 0(et)
	andi et, et, 0x200
	bne et, r0, AUDIO_PLAY
	br EXIT_HANDLER
	
AUDIO_RECORD:
	stw r8, 12(sp)
	stw r9, 16(sp)
	stw r10, 20(sp)
	
	movia r8, recordindex		#grab current recording index
	ldwio et, 0(r8)
	
	movia r8, ADDR_AUDIODACFIFO
	movia r9, songone
	
	srli et, et, 1
	muli et, et, 2				#move song pointers to correct index
	add r9, r9, et

	
	ldwio et, 8(r8)				#load audio values into memory
	ldwio et, 12(r8)
	srli et, et, 16
	sth et, 0(r9)
	
	movia r8, recordindex		#increment recording index
	ldwio et, 0(r8)
	addi et, et, 1
	stwio et, 0(r8)
	
	ldw r8, 12(sp)
	ldw r9, 16(sp)
	ldw r10, 20(sp)
	br EXIT_HANDLER
	
	
AUDIO_PLAY:
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
	
	
EXIT_HANDLER:
	ldw et, 4(sp)
	wrctl ctl1, et
	ldw et, 0(sp)
	ldw ea, 8(sp)
	addi sp, sp, 24
	addi ea, ea, -4
	eret


############################# MAIN #############################

.section .text	
main:
	movia sp, SP_START
MAINLOOP:
	movia r2, ADDR_SWITCHES
	ldbio r3, 0(r2)
	
	#set read interrupt enable to 1
	movia r8, PS2CONTROLLER
	ldw r9, 4(r8)
	ori r9, 0x1
	stw r9, 4(r8)

	movia r8, mode
	stb r3, 0(r8)

	call VGA
	andi r3, r3, 0b1
	beq r3, r0, NOTRECORD

	movia r8, TIMER	
	movui r9, %lo(PERIOD)
	stwio r9, 8(r8)
	movui r9, %hi(PERIOD)
	stwio r9, 12(r8)
	stwio r0, 0(r8)

	movi r9, 0b10000001
	wrctl ctl3, r9				#enable IRQ0 (timer) and IRQ7 (PS2 controller)

	movi r9, 0b1				#enable external interrupts (PIE)
	wrctl ctl0, r9
	
	#reset TIME_TRACE to 0 then call record
	movia r8, TIME_TRACE
	stw r0, 0(r8)
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
	movia r8, TIME_TRACE
	stw r0, 0(r8)
	call PLAY
	br MAINLOOP
NOTPLAY:
	ldbio r3, 0(r2)
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
NOTHALFX:	
	call ECHO
	br MAINLOOP

RECORD:
	addi sp, sp, -4
	stw ra, 0(sp)

	movia r8, ADDR_AUDIODACFIFO			#enable audio codec for read interrupts
	movi r9, 0b1
	stwio r9, 0(r8)
	
	movi r9, 0b11000001		#enable IRQ6 for audio codec (with timer)
	wrctl ctl3, r9
	
	movi r9, 0b1				#enable external interrupts
	wrctl ctl0, r9
	
	movia r9, recordindex
	stw r0, 0(r9)
	movia r11, ADDR_SWITCHES
	RECORDLOOP:	
		movia r13, mode
		stb r3, 0(r13)
		call VGA

		ldbio r10, 0(r11)			#check if they switch it off
		beq r10, r0, STOPRECORD
		ldw r10, 0(r9)				#check if we've reached max record length
		movia r12, SONG_LENGTH
		bge r10, r12, STOPRECORD
		br RECORDLOOP
		
	STOPRECORD:
		#disable interrupts
		stwio r0, 0(r8)
		wrctl ctl3, r0
		wrctl ctl0, r0
		
		ldw ra, 0(sp)
		addi sp, sp, 4
		ret
	
PLAY:
	addi sp, sp, -4
	stw ra, 0(sp)
	movia r8, ADDR_AUDIODACFIFO			#enable audio codec for read interrupts
	movi r12, 0b1000
	stw r12, 0(r8)
	stw r0, 0(r8)
	movia r15, ADDR_SWITCHES
	movia r10, SONG_LENGTH
	movia r11, playindex
	stw r0, 0(r11)

	
PLAYLOOP:
	movia r2, ADDR_SWITCHES			#load the slider switch address into r2
	ldbio r3, 0(r2)					#r3 contains the slider switch info
	movia r8, mode
	stb r3, 0(r8)
	call VGA

	ldw r12, 0(r11)				#r12 holds playindex
	bgt r4, r0, SPEEDUP
	blt r4, r0, SLOWDOWN
	br CHECKINDEX

SLOWDOWN:
	muli r9, r4, -1
	srl r12, r12, r9
	br CHECKINDEX
SPEEDUP:
	sll r12, r12, r4
	br CHECKINDEX


CHECKINDEX:
	ble r5, r0, PITCHNORMAL
PITCHUP:
	muli r12, r12, 2
PITCHNORMAL:
	bge r12, r10, STOPPLAY
	ldbio r16, 0(r15)			#check if they switch it off
	beq r16, r0, STOPPLAY
	
	ldwio r9,4(r8)      # Read fifospace register 
	srli r9, r9, 16    # Extract # of spaces available in Output Channel FIFO 
	andi r20, r9, 0xff
	beq r20, r0, PLAYLOOP # If no samples in FIFO, go back to start 
	andi r20, r9, 0xff00
	beq r20, r0, PLAYLOOP

	movia r13, songone
	srli r12, r12, 1
	muli r12, r12, 2
	add r13, r13, r12

	
	ldh r16, 0(r13)				#load from songone
	slli r16, r16, 16
	stwio r16, 8(r8)
	stwio r16, 12(r8)
	
	ldw r12, 0(r11)	
	addi r12, r12, 1
	stw r12, 0(r11)
	br PLAYLOOP 
	
STOPPLAY:
	stwio r0, 0(r8)
	wrctl ctl3, r0
	wrctl ctl0, r0

	ldw ra, 0(sp)
	addi sp, sp, 4
	ret
	

ECHO:
  
  movia r2,ADDR_AUDIODACFIFO
  ldwio r3,4(r2)      /* Read fifospace register */
  andi  r3,r3,0xff    /* Extract # of samples in Input Right Channel FIFO */
  beq   r3,r0,ECHODONE  /* If no samples in FIFO, go back to start */

  ldwio r3,8(r2)
  stwio r3,8(r2)      /* Echo to left channel */
  
  ldwio r3,12(r2)
  stwio r3,12(r2)  /* Echo to right channel */
 ECHODONE:
  ret
  

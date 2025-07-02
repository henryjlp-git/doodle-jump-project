.data
	GPAddress: .word 0x10008000    
	
	backgroundColor: .word 0xADD8E6	         # Light blue
	platformColor: .word 0x5C4033		 # Dark brown
	characterColor: .word 0xFFA500		 # Orange 
	redLava: .word 0xE42217		 
	black: .word 0x000000			
	textColor: .word 0x02075d		# Blue
	platforms: .space 16			# Array of platforms
		 
.text

main:
	lw $t0, GPAddress # $t0 stores $GP address which is the display address 
	la $t1, platforms # t1 = platforms
	jal ColorBackground  
	jal startingPlatforms
	
	lw $t2, 12($t1)     # t2 stores location of character
	addi $t2, $t2, -496 # Makes character 3 pixels above middle of lowest platform
	jal drawCharacter
	
	li $t3, 0 # Jump counter, if <20, jump up, if 20, jump down until lose/platform
	li $t4, 0 # Score counter, score += 1 if new platform is made
	li $t5, 8 # Difficulty level. Easiest is lvl 8, hardest is lvl 0
	# Difficulty increases each time score goes up by 10
	li $t6, 1 # a variable to help relate score and updating difficulty 
	
mainLoop:
	jal Input  	# Detect input
	
	beq $t3, 18, GoDown	

GoUp:
	addi $t2, $t2, -128
	addi $t3, $t3, 1
	j mainLoop2
	
GoDown: # check if character fell down
	addi $t2, $t2, 128
	jal FellInLava
	jal checkJump

mainLoop2:
	jal checkMoveScreen
	
redrawScreen:
	jal ColorBackground
	
	jal InGameScore # difficulty adjusted here
	li $s0, 0
	addi $s0, $t0, 0  # place score at the top left
	move $s6, $s3
	jal drawDigit
	addi $s0, $s0, 16
	move $s6, $s4
	jal drawDigit
	addi $s0, $s0, 16
	move $s6, $s5
	jal drawDigit
	
	jal drawPlatforms
	jal drawCharacter
	
	j mainLoop
	
Input:
	li $v0, 32
	li $a0, 50
	syscall
	lw $s0, 0xffff0000
	beq $s0, 1, checkInput # There is input
	jr $ra # No input
	
checkInput:
	lw $s1, 0xffff0004
	beq $s1, 97, InputIsA # input is A
	beq $s1, 100, InputIsD # input is D
	jr $ra # input is not A or D
	
InputIsA:
	addi $t2, $t2, -4 # move character one pixel to the left
	jr $ra

InputIsD:
	addi $t2, $t2, 4 # move character one pixel to the right
	jr $ra
	
FellInLava: # check if character fell in the lava
	li $s0, 0
	addi $s0, $t0, 4096
	# if character location greater than bottom-right pixel location, end game
	bgt $t2, $s0, gameOver
	jr $ra
	
gameOver:
	j exit
	
checkJump:
	li $s0, 0
	li $s1, 4
	la $s2, 0($t1)

checkJumpLoop:
	beq $s0, $s1, checkJumpEnd
	lw $s3, 0($s2)
	li $s4, 0 # leftmost possible pixel
	li $s5, 0 # rightmost possible pixel
	li $s6, 8 # to help adjust rightmost pixel based on difficulty
	sub $s6, $s6, $t5
	mul $s6, $s6, 4
	addi $s4, $s3, -260
	addi $s5, $s3, -220
	sub $s5, $s5, $s6
	bge $t2, $s4, restartJump

checkJumpLoopCont:
	addi $s0, $s0, 1
	addi $s2, $s2, 4
	j checkJumpLoop
	
restartJump:
	bgt $t2, $s5, checkJumpLoopCont
	li $t3, 0

checkJumpEnd:
	jr $ra
	
	
checkMoveScreen:
	li $s0, 0
	addi $s0, $t0, 896
	blt $t2, $s0, moveScreen
	jr $ra

moveScreen:
	li $s0, 0
	la $s2, 0($t1)
	addi $s0, $s2, 12
	add $s4, $t0, 3968 #location of last row
	lw $s3, 0($s0) #location of bottom platform
	addi $t2, $t2, 128 #character go down one row
	bge $s3, $s4, addPlatform

movePlatformsDown:
	li $s5, 0
	li $s6, 16
	li $s4, 0

movePlatformsLoop:
	beq $s5, $s6, movePlatformsEnd
	la $s7, 0($t1)
	add $s4, $s7, $s5
	lw $s3, 0($s4)
	addi $s3, $s3, 128
	sw $s3, 0($s4)
	addi $s5, $s5, 4
	j movePlatformsLoop
	
movePlatformsEnd:
	jr $ra

addPlatform:
	li $v0, 42
	li $a1, 32
	sub $a1, $a1, $t5
	syscall
	
	# multiply random number by 4
	li $s1, 4
	mul $s1, $s1, $a0
	add $s1, $t0, $s1  # location of new platform, one row above screen
	addi $s1, $s1, -128
	
	addi $t4, $t4, 1 #s core increases by 1
	
	# now we want to shift the platform array
	li $s5, 12 # loop counter
	li $s6, 0 # loop counter end, we will keep adding 4.
	li $s4, 0

shiftPlatforms:
	beq $s5, $s6, shiftPlatformsEnd
	la $s7, 0($t1)
	add $s4, $s7, $s5 # platform at index ($s5/4) location
	lw $s0, -4($s4) # get previous platform	
	sw $s0, 0($s4) # store at current
	addi $s5, $s5, -4
	j shiftPlatforms

shiftPlatformsEnd:
	li $s4, 0
	la $s7, 0($t1)
	addi $s4, $s7, 0
	sw $s1, 0($s4) # store new platform at index 0 of platform array
	j movePlatformsDown
	
############################## DRAWING FUNCTIONS ##########################
# Backgroud coloring:
ColorBackground:
	add $s0, $t0, $zero
	li $s1, 0 # loop counter
	li $s2, 960 # loop counter end condition
	li $s4, 1024

ColorBackgroundLoop:
	beq $s1, $s2, ColorBackground2 # loop condition check
	lw $s3, backgroundColor # s3 stores background colour
	sw $s3, 0($s0) # draw current pixel
	addi $s0, $s0, 4 # increment by 4 (go to next) 
	addi $s1, $s1, 1 # increment loop counter by 1
	j ColorBackgroundLoop # back to start of loop
ColorBackground2:
	beq $s1, $s4, ColorBackgroundEnd
	lw $s5, redLava
	sw $s5, 0($s0)
	addi $s0, $s0, 4
	addi $s1, $s1, 1
	j ColorBackground2

ColorBackgroundEnd:
	jr $ra
	
ColorBackgroundGameOver:
	add $s0, $t0, $zero
	li $s1, 0 # loop counter
	li $s2, 1024 # loop counter end condition

ColorBackgroundLoopGameOver:
	beq $s1, $s2, ColorBackgroundEndGameOver # loop condition check
	lw $s3, redLava # s3 stores background colour
	sw $s3, 0($s0) # draw current pixel
	addi $s0, $s0, 4 # increment by 4 (go to next) 
	addi $s1, $s1, 1 # increment loop counter by 1
	j ColorBackgroundLoopGameOver # back to start of loop

ColorBackgroundEndGameOver:
	jr $ra

startingPlatforms:
	li $s0, 0 # loop counter
	li $s1, 4 # loop counter end 0-3 = 4 platforms
	li $s4, 896 # row 7, if indexing start at 0
	li $s6, 0
	add $s6, $s6, $t1
	
startingPlatformsLoop: 
	beq $s0, $s1, startingPlatformsEnd
	# generates a random number between 0 and 23, platform will have the length 9
	li $v0, 42
	li $a1, 24 
	syscall
	
	# multiply rand 4
	li $s2, 4
	mul $s3, $s2, $a0
	
	# draw the platform
	add $s5, $t0, $s4
	add $s5, $s5, $s3
	lw $s7, platformColor	# $s7 contains the platform colour 
	sw $s7, 0($s5) # first position at 0($s5)
	sw $s7, 4($s5)
	sw $s7, 8($s5)
	sw $s7, 12($s5)
	sw $s7, 16($s5)
	sw $s7, 20($s5)
	sw $s7, 24($s5)
	sw $s7, 28($s5)
	sw $s7, 32($s5) # last position at 32($s5)
	addi $s4, $s4, 1024
	addi $s0, $s0, 1
	
	# put the platform in the array of platform
	sw $s5, 0($s6)
	addi $s6, $s6, 4
	
	j startingPlatformsLoop
	

startingPlatformsEnd:
	jr $ra

drawPlatforms:
	li $s0, 0 # loop counter
	li $s1, 4 # loop counter max
	la $s2, ($t1)

drawPlatformsLoop:
	beq $s0, $s1, drawPlatformsEnd # end loop when s0 is equal to 4
	lw $s7, platformColor	# s7 stores the platform color code
	lw $s5, 0($s2)
	li $s3, 4
	li $s4, 0
	add $s4, $s4, $t5
	addi $s4, $s4, 1
	mul $s4, $s4, $s3
	li $s3, 0

drawPlatformsLoopLoop:
	beq $s3, $s4, drawPlatformsLoop2
	add $s6, $s5, $s3
	sw $s7, 0($s6)
	addi $s3, $s3, 4
	j drawPlatformsLoopLoop

drawPlatformsLoop2:
	addi $s0, $s0, 1
	addi $s2, $s2, 4
	j drawPlatformsLoop

drawPlatformsEnd:
	jr $ra



# drawing character
drawCharacter:
		lw $s1, characterColor # $t0 stores the character color code
		move $s0, $t2
		sw $s1, -256($s0)
		sw $s1, -132($s0)
		sw $s1, -124($s0)
		sw $s1, -4($s0)
		sw $s1, 4($s0)
		
		jr $ra	
	


# Score
InGameScore :
	lw $s1, textColor	# t1 has the color of the text
	
	 #know the triple, double, and single digits of the score
	li $s2, 100
	div $t4, $s2
	mflo $s3 # hundredths
	
	li $s2, 10
	mfhi $s4  #tenths
	div $s4, $s2
	mflo $s4
	mfhi $s5  # ones
	
	beq $s4, 0, drawInGameScoreEnd
	beq $s5, 0,  raiseDifficulty
	
drawInGameScoreEnd:
	jr $ra
# Difficulty update, the platforms get shorter the higher the score
raiseDifficulty:
	beq $t5, 0, drawInGameScoreEnd
	bne $t6, $s4, drawInGameScoreEnd
	addi $t6, $t6, 1
	addi $t5, $t5, -1
	j drawInGameScoreEnd


# Drawing the score on screen
drawDigit:
	beq $s6, 0, drawZero
	beq $s6, 1, drawOne
	beq $s6, 2, drawTwo
	beq $s6, 3, drawThree
	beq $s6, 4, drawFour
	beq $s6, 5, drawFive
	beq $s6, 6, drawSix
	beq $s6, 7, drawSeven
	beq $s6, 8, drawEight
	beq $s6, 9, drawNine
	addi $s0, $s0, 16
	jr $ra 
	
    
  ####################################Drawing score#######################################
# Drawing each digit
drawZero:
# drawing the upper horizontal line
	lw $s1, textColor     # Setting the color in $s1
	sw $s1, 0($s0)		# Filling 
	sw $s1, 4($s0)
	sw $s1, 8($s0)
# left vertical line
	sw $s1, 128($s0)
	sw $s1, 256($s0)
	sw $s1, 384($s0)
	sw $s1, 512($s0)
# lower horizontal line
	sw $s1, 516($s0)
	sw $s1, 520($s0)
# right vertical line
	sw $s1, 392($s0)
	sw $s1, 264($s0)
	sw $s1, 136($s0)
	jr $ra
	
drawOne:
	lw $s1, textColor
	sw $s1, 4($s0)
	sw $s1, 132($s0)
	sw $s1, 128($s0)
	sw $s1, 260($s0)
	sw $s1, 388($s0)
	sw $s1, 516($s0)
	jr $ra
	
drawTwo:
	lw $s1, textColor
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 136($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 384($s0)
	sw $s1, 520($s0)
	sw $s1, 516($s0)
	sw $s1, 512($s0)
	jr $ra
	
drawThree:
	lw $s1, textColor
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 136($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 392($s0)
	sw $s1, 512($s0)
	sw $s1, 516($s0)
	sw $s1, 520($s0)
	jr $ra
	
drawFour:
	lw $s1, textColor
	sw $s1, 0($s0)
	sw $s1, 8($s0)
	sw $s1, 128($s0)
	sw $s1, 136($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 392($s0)
	sw $s1, 520($s0)
	jr $ra
	
drawFive:
	lw $s1, textColor
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 128($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 392($s0)
	sw $s1, 520($s0)
	sw $s1, 516($s0)
	sw $s1, 512($s0)
	jr $ra
	
drawSix:
	lw $s1, textColor
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 128($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 392($s0)
	sw $s1, 520($s0)
	sw $s1, 516($s0)
	sw $s1, 512($s0)
	sw $s1, 384($s0)
	jr $ra
	
drawSeven:
	lw $s1, textColor
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 136($s0)
	sw $s1, 264($s0)
	sw $s1, 392($s0)
	sw $s1, 520($s0)
	jr $ra
	
drawEight:
	lw $s1, textColor
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 128($s0)
	sw $s1, 136($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 384($s0)
	sw $s1, 392($s0)
	sw $s1, 520($s0)
	sw $s1, 516($s0)
	sw $s1, 512($s0)
	jr $ra
	
drawNine:
	lw $s1, textColor
	sw $s1, 0($s0)
	sw $s1, 4($s0)
	sw $s1, 8($s0)
	sw $s1, 128($s0)
	sw $s1, 136($s0)
	sw $s1, 256($s0)
	sw $s1, 260($s0)
	sw $s1, 264($s0)
	sw $s1, 392($s0)
	sw $s1, 520($s0)
	sw $s1, 516($s0)
	sw $s1, 512($s0)
	jr $ra
# Drawing score at the end of the game	
drawScoreEndGame:
	lw $s1, textColor
	
	# get triple, double, and single digits
	li $s2, 100
	div $t4, $s2
	mflo $s3 # hundredths
	
	li $s2, 10
	mfhi $s4  # tenths
	div $s4, $s2
	mflo $s4
	mfhi $s5  # ones
	
	jr $ra 
	





####################################################### GAME OVER #############################################################


exit:
	# Paint Background with Lava Color
	jal ColorBackgroundGameOver
		
	###########################################
	# Drawing score at the endScreen
	jal drawScoreEndGame
	li $s0, 0
	addi $s0, $t0, 2712
	move $s6, $s3
	jal drawDigit
	addi $s0, $s0, 16
	move $s6, $s4
	jal drawDigit
	addi $s0, $s0, 16
	move $s6, $s5
	jal drawDigit
	li $v0, 10 # end program
	syscall

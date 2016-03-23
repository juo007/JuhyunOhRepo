# Tic-Tac-Toe Minimax
#
# Partner1: SHEUNG MAX TSOI
# Partner2: JUHYUN OH

.data

computer_won:
	.asciiz "Computer won!\n"
player_won:
    .asciiz "Player won!\n"
print_tie_game:
    .asciiz "Tie game!\n"
prompt_player_move:
	.asciiz "Please enter move location (1-9): "
board_divider:
    .asciiz "*---*---*---*\n"
board_X:
    .asciiz "| X "
board_O:
    .asciiz "| O "
board_num:
    .asciiz "| "
board_space:
    .asciiz " "
board_end_line:
    .asciiz "|\n"
newline:
	.asciiz "\n"

.globl player_move
.globl minimax
.globl display_board
.globl update_board
.globl main
.globl check_win_tie

.text

main:	
	# Initializing main procedure:
	addiu	$sp, $sp, -12		# Allocate space for stack-frame
	sw 	$ra, 4($sp) 		# Store return address
	sw 	$fp, 8($sp) 		# Store frame pointer
	sw	$s0, 12($sp)		# Store s0 (we will use this register for holding the board)
	addiu	$fp, $sp, 12 		# Update the curernt frame pointer

# Preamble
	add $s0, $0, $0			# Initialize board to empty
	#li $s0, 1689			# Test board

main_loop:
    	add $a0, $s0, $0		# Load board into a0 and call display_board
    	jal display_board
 
    	add $a0, $s0, $0		# Load board into a0 and call player_move
    	jal player_move
    
# Update board
	add $a0, $s0, $0		# Load board into a0
	li  $a1, 1			# Set player to human
	add $a2, $v0, $0		# Get move from player_move and set to a2

	jal update_board

	add $s0, $v0, $0		# Save updated board to s0
	add $a0, $s0, $0		# Load board into a0 and call check_win_tie 
	jal check_win_tie

# We have 0-3 in v0, 0 = continue, 1 = human, 2 = computer, 3 = tie
	beq $v0, $0, no_win		# Continue on to computer move
	slti $t0, $v0, 2		# If it's less, player win, more = tie (computer cannot win on a human move)
	beq $t0, $0, tie_game
	j player_win

no_win:
	add $a0, $s0, $0		# Load board into a0 and call display_board
	jal display_board

	add $a0, $s0, $0		# Load board into a0, 0 depth into a1 and call minimax
	add $a1, $0, $0
	jal minimax
    
# Update board
	add $a0, $s0, $0		# Load board into a0
	li  $a1, 2			# Set player to human
	add $a2, $v0, $0		# Get move from minimax and set to a2

	jal update_board

	add $s0, $v0, $0		# Save updated board to s0
	add $a0, $s0, $0		# Load board into a0 and call check_win_tie 
	jal check_win_tie

# We have 0-3 in v0, 0 = continue, 1 = human, 2 = computer, 3 = tie
	beq $v0, $0, main_loop		# Continue on to top of loop
	slti $t0, $v0, 3		# If it's less, computer win, equal = tie (computer cannot win on a human move)
	beq $t0, $0, tie_game

# computer_win:
	# Print the board
	add $a0, $s0, $0		# Load board into a0 and call display_board
	jal display_board
    
# Print winning message
	la  $a0, computer_won
	li  $v0, 4
	syscall

	j end_main

player_win:
# Print the board
	add $a0, $s0, $0		# Load board into a0 and call display_board
	jal display_board
    
# Print winning message
	la  $a0, player_won
	li  $v0, 4
	syscall

	j end_main

tie_game:
# Print the board
	add $a0, $s0, $0		# Load board into a0 and call display_board
	jal display_board
    
# Print winning message
	la  $a0, print_tie_game
	li  $v0, 4
	syscall

end_main:
# Finalizing main procedure:
	lw	$ra, 4($sp)		# Load previous return address
	lw 	$fp, 8($sp)		# Load previous frame pointer
	lw	$s0, 12($sp)		# Restore previous s0
	addiu	$sp, $sp, 12 		# Pop the frame from the stack
	jr	$ra			# Jump back to return address

# END OF main

player_move:
# a0 is board state
# v0 is move position

	add $t0, $a0, $0		# Store off input so syscall doesn't overwrite

invalid_input:
	li  $v0, 4			# prompt user for input (up to syscall)
	la  $a0, prompt_player_move
	syscall

	li  $v0, 5			# get user input
	syscall

	blez    $v0, invalid_input	# input < 1
	sub     $t1, $v0, 9
	bgtz     $t1, invalid_input	# input > 9

	addi    $v0, $v0, -1		# Convert 1-9 to 0-8 for actual use
	addi    $t1, $0, 3		# set 2 bit mask
	sllv    $t1, $t1, $v0		# shift mask over to appropriate entry
	sllv    $t1, $t1, $v0		# since each entry is 2 bits (0 empty, 1 = player, 2 = computer), needs double shifting
	and     $t2, $t1, $t0		# and mask and board status
    
	bne     $t2, $0, invalid_input	# loop if entry occupied

	jr      $ra
    
# end of player_move

minimax:
# Implements the minimax algorithm for computer player
# $a0 holds the board state
# $a1 holds the current recursion depth
# $v0 returns the best score for that depth, unless depth equals zero, in which case it returns the tile position [0-8] of that best move
# $a2 holds the MOVE COUNTER
# $a3 holds the SCORES ARRAY POINTER

	# Allocate space for stack-frame:
	addiu	$sp, $sp, -64		# Allocate space for stack-frame
	sw 	$ra, 4($sp) 		# Store return address
	sw 	$fp, 8($sp) 		# Store frame pointer
	addiu	$fp, $sp, 64		# Update the current frame pointer

	#call check_win_tie on present board
	jal	check_win_tie

	# Test base case
	beq	$v0, $0, algorithm	# Branch to algorithm if $v0 == 0 (no win)

# return different results
results:
	slti	$t0, $v0, 2		# Set $t0 = 1 if $v0 < 2 ($v0 == 1 (human won))
	bne	$t0, $0, result_human	# Branch to result_human if $t0 != 0 ($t0 == 1)
	slti	$t0, $v0, 3		# Set $t0 = 1 if $v0 < 3 ($v0 == 2 (computer won))
	bne	$t0, $0, result_computer	# Branch to result_computer if $t0 != 0 ($t0 == 1)
# result_tie
	addi	$v0, $0, 0		# Set $v0 = 0
	j	end_minimax		# Jump to end_minimax

result_human:
	addi	$v0, $a1, -10		# Set $v0 = depth - 10
	j	end_minimax		# Jump to end_minimax
	
result_computer:
	addi	$t0, $0, 10		# Set $t0 to 10
	sub	$v0, $t0, $a1		# Set $v0 = 10 - depth
	j	end_minimax		# Jump to end_minimax

algorithm:
# Not base case, generate moves and test with minimax
	addi	$a2, $0, 0		# Initialize $a2 (move counter) to 0
	addiu	$a3, $sp, 28		# Initialize $a3 (scores array pointer) to memory location of scores[0]
	addi	$s1, $a0, 0		# Load board into $s1 (shifted board)
	 
loop_minimax:
	andi	$t4, $s1, 3		# Store last 2 bits into $t4
	srl	$s1, $s1, 2		# Shift board right by 2 bits, save into $s1
	bne	$t4, $0, full_flag	# Branch to full_flag if $t4 != 0 (not empty)
# now, board[i] == 0
	sw	$a0, 12($sp)		# Store $a0 (board state) BEFORE update_board
	sw	$a1, 16($sp)		# Store $a1 (current recursion depth) BEFORE update_board
	andi	$a1, $a1, 1		# $a1 = 0 if even (computer), else $a1 = 1 if odd (human)
	slti	$a1, $a1, 1		# $a1 = 1 if $a1 was 0 (computer), else $a1 = 0 if $a1 was 1 (human)
	addi	$a1, $a1, 1		# Increment $a1, so 2 = computer and 1 = human

	jal	update_board		# Call update_board (changes $a1 and $v0)

	addi	$a0, $v0, 0		# Load the updated board $v0 into $a0
	lw	$a1, 16($sp)		# Restore previous $a1 (before update_board)
	addi	$a1, $a1, 1		# Increment $a1 (depth++)
	sw	$a2, 20($sp)		# Store $a2 (move counter)
	sw	$a3, 24($sp)		# Store $a3 (scores array pointer)
	sw	$s1, 64($sp)		# Store $s1 (current shifted board)

	jal 	minimax			# Call minimax (assume it updates $v0)

	lw	$a0, 12($sp)		# Restore previous $a0 (before update_board)
	lw	$a1, 16($sp)		# Restore previous $a1 (before update_board)
	lw	$a2, 20($sp)		# Restore previous $a2
	lw	$a3, 24($sp)		# Restore previous $a3
	lw	$s1, 64($sp)		# Restore previous $s1
	sw	$v0, 0($a3)		# Store return value of minimax $v0 to scores[i]
	j	end_loop_minimax	# Jump to end_loop_minimax

full_flag:
# push “full” flag onto  the current tile’s memory location on the stack frame
	addi	$t3, $0, 50		# Load 50 (full flag) into $t3
	sw	$t3, 0($a3) 		# Store 50 into scores[i]

end_loop_minimax:
	addi	$a2, $a2, 1		# Increment $a2 (move counter++)
	addi	$a3, $a3, 4		# Increment $a3 by 4 (scores array pointer to next tile)
	addi	$t2, $0, 9		# Load 9 into $t2
	bne 	$a2, $t2, loop_minimax	# Branch to loop_minimax if $a2 != $t2 (move counter < 9)

check_depth:
	addiu 	$a3, $sp, 28		# Reinitialize scores array pointer to memory location scores[0]
	lw	$v0, 0($a3)		# Load the value stored in scores[0] into $v0
	addi	$t1, $0, 0		# Load 0 into $t1 (set i = 0)
	addi	$t2, $0, 8		# Load 8 (end of loop) into $t2
	addi	$t3, $0, 50		# Load 50 (full flag) into $t3
	beq	$a1, $0, return_index	# Branch to return_index if $a1 == 0
	andi	$a1, $a1, 1		# Set $a1 = 0 if even (computer), set $a1 = 1 if odd (human)
	beq	$a1, $0, return_max	# Branch to return_max if depth%2 == 0

loop_min:
	addi	$a3, $a3, 4		# Increment $a3 by 4 (point to next scores[i])
	lw	$t0, 0($a3)		# Load value stored in scores[i] into $t0
	slt	$t4, $t0, $v0		# If $t0 < $v0, set $t3 = 1 (scores[i] < $v0), else set $t3 = 0
	bne	$t4, $0, set_min	# Branch to set_min if $t3 != 0 ($t3 == 1)
	addi	$t1, $t1, 1		# Increment $t1 (i++)
	beq	$t1, $t2, end_minimax	# Branch to end_minimax if $t1 == $t2 (i == 8)
	j	loop_min		# Jump to loop_min
set_min:
	addi	$v0, $t0, 0		# Load $t0 into $v0 ($v0 = scores[i])
	addi	$t1, $t1, 1		# Increment $t1 (i++)
	bne	$t1, $t2, loop_min	# Branch to loop_min if $t1 != $t2 (i != 8)
	j	end_minimax		# Jump to end_minimax

return_max:
	beq	$v0, $t3, set_negative	# Branch to set_negative if $v0 == $t3 (scores[0] == 50)
	j	loop_max		# Jump to loop_max
set_negative:
	addi	$v0, $0, -50		# Load -50 into $v0, waiting to be replaced
loop_max:
	addi	$a3, $a3, 4		# Increment $a3 by 4 (point to next scores[i])
	lw	$t0, 0($a3)		# Load value of scores[i] into $t0
	beq	$t0, $t3, max_full_flag	# Branch to max_full_flag if $t0 == $t3 (scores[i] == 50)
	slt	$t4, $v0, $t0		# If $v0 < $t0, set $t4 = 1 ($v0 < scores[i]), else set $t4 = 0
	bne	$t4, $0, set_max	# Branch to set_max if $t4 != $t0 ($t4 == 1)
	addi	$t1, $t1, 1		# Increment $t1 (i++)
	bne	$t1, $t2, loop_max	# Branch to loop_max if $t1 != $t2 (i != 8)
	j	end_minimax		# Jump to end_minimax
max_full_flag:
	addi	$t1, $t1, 1		# Increment $t1 (i++)
	bne	$t1, $t2, loop_max	# Branch to loop_max if $t1 != $t2 (i != 8)
	j	end_minimax		# Jump to end_minimax
set_max:	
	addi	$v0, $t0, 0		# Load $t0 into $v0 ($v0 scores[i])
	addi	$t1, $t1, 1		# Increment $t1 (i++)
	bne	$t1, $t2, loop_max	# Branch to loop_max if $t1 != $t2 (i != 8)
	j	end_minimax		# Jump to end_minimax

return_index:
# Use $v1 to store the max value, $v0 stores the index at the max value
	lw	$v1, 0($a3)		# Load the value stored in scores[0] into $v1
	addi	$v0, $0, 0		# Set $v0 = 0 (index = 0)
	beq	$v1, $t3, index_negative	# Branch to index_negative if $v1 == $t3 (scores[0] == 50)
	j 	loop_index		# Jump to loop_index
index_negative:
	addi	$v1, $0, -50		# Load -50 into $v1, waiting to be replaced	
loop_index:
	addi	$a3, $a3, 4		# Increment $a3 by 4 (point to next scores[i])
	lw	$t0, 0($a3)		# Load value of scores[i] into $t0
	beq	$t0, $t3, index_full_flag	# Branch to index_full_flag if $t0 == $t3 (scores[i] == 50)
	slt	$t4, $v1, $t0		# If $v1 < $t0, set $t4 = 1 ($v1 < scores[i]), else set $t4 = 0
	bne	$t4, $0, set_max_index	# Branch to set_max_index if $t4 != $t0 ($t4 == 1)
	addi	$t1, $t1, 1		# Increment $t1 (i++)
	bne	$t1, $t2, loop_index	# Branch to loop_max if $t1 != $t2 (i != 8)
	j	end_minimax		# Jump to end_minimax
index_full_flag:
	addi	$t1, $t1, 1		# Increment $t1 (i++)
	bne	$t1, $t2, loop_index	# Branch to loop_index if $t1 != $t2 (i != 8)
	j	end_minimax		# Jump to end_minimax
set_max_index:	
	addi	$v1, $t0, 0		# Load $t0 into $v1 ($v1 = scores[i])
	addi	$t1, $t1 , 1		# Increment $t1 (i++)
	addi	$v0, $t1, 0		# Load $t1 into $v0 ($v0 = i)
	bne	$t1, $t2, loop_index	# Branch to loop_max if $t1 != $t2 (i != 8)
	j	end_minimax		# Jump to end_minimax

	# Finalizing minimax
end_minimax:
	lw	$ra, 4($sp) 		# Restore previous return address
	lw 	$fp, 8($sp) 		# Restore previous frame pointer
	addiu	$sp, $sp, 64		# Pop the frame from the stack
	jr	$ra			# Jump back to return address

# End of minimax


display_board:
# Prints out the board, X's for player's moves, O's for computer's moves, and tile number for blank spaces
# a0 is board state
# v0 is unused

# preamble
	add $t0, $a0, $0		# Store off input so syscall doesn't overwrite
    	li  $t6, 1			# Tile counter (1-9 for printing)
    	li  $t7, 3			# Number of rows-1 (end on zero)

# header
	li  $v0, 4			# Set up for printing board divider
    	la  $a0, board_divider
    	syscall

print_outer_loop:
	li  $t8, 3			# Number of columns-1 (end on zero) 

print_inner_loop:
	andi    $t2, $t0, 3		# Mask for tile in question
	beq     $t2, $0, print_number	# Empty tile, just print the number of that space
	addi    $t2, $t2, -1		# Nonzero, subtract one to see if value was 1 or 2 (now 0 or 1)
	beq     $t2, $0, print_player	# If zero, then original number was in fact a 1: the player

print_computer:				# Tile originally a 2: the computer, print an "| O "
	li  $v0, 4
	la  $a0, board_O
	syscall
	j print_inner_loop_end

print_player:				# Print "| X "
	li  $v0, 4
	la  $a0, board_X
	syscall
	j print_inner_loop_end

print_number:				# Print "| _ ", where _ is the tile number 
	li  $v0, 4
	la  $a0, board_num		# Print "| "
	syscall
	li  $v0, 1			# Print tile number
	add $a0, $t6, $0		# Set a0 to the tile counter and print value out
	syscall
	li  $v0, 4
	la  $a0, board_space		# Print " "
	syscall

print_inner_loop_end:
	addi    $t6, $t6, 1		# increment tile counter
	srl     $t0, $t0, 2		# shift over to next tile
	addi    $t8, $t8, -1		# decrement column counter

	bne     $t8, $0, print_inner_loop	# Loop on tiles in a row

# End of row
	li  $v0, 4			# print out "|\n" to close out end of row
	la  $a0, board_end_line
	syscall
	li  $v0, 4			# Set up for printing row spacer
	la  $a0, board_divider
	syscall

	addi    $t7, $t7, -1		# decrement row counter
	bne     $t7, $0, print_outer_loop	#loop on rows

# 2 newlines at end of board print 
	li  $v0, 4
	la  $a0, newline
	syscall
	li  $v0, 4
	la  $a0, newline
	syscall

	jr  $ra

# End of display_board

update_board:
# Procedure updates the board based on the move and player number
# a0 holds the board (as passed to update_board)
# a1 holds the player's or computer's ID (1 and 2, respectively)
# a2 holds the tile to update (0-8)
# v0 holds the updated board (to return to the calling function)

	sllv $a1, $a1, $a2		# shift the computer/player ID over to the respective tile
	sllv $a1, $a1, $a2		# by doing a sllv twice (since it's 2-bits wide)

	or  $v0, $a0, $a1		# bitwise or will overwrite the empty values in that location with computer/player ID

	jr  $ra

# End update_board

check_win_tie:
# Procedure returns whether player or computer wins (values 1 and 2, respectively),
# ties (3), or is still in progress (0)
# a0 holds the board
# v0 holds the 0-3, as appropriate
# Horizontal Check--faster to manually loop unwind

# horizontal_check
FirstRow:
	add	$t0, $a0, $0		# Load board into $t0
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 1
	beq	$t1, $0, SecondRow	# Branch to SecondRow if extracted bit is empty
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 2
	andi	$t2, $t0, 3		# Extract the 2 bits stored in position 2
	bne	$t2, $t1, SecondRow	# Branch to SecondRow if extracted bits not equal
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 3
	andi	$t3, $t0, 3		# Extract the 2 bits stored in position 3
	beq	$t3, $t2, Win		# Branch to Win if extracted bits are equal
	
SecondRow: 
	add	$t0, $a0, $0		# Load board into $t0
	srl	$t0, $t0, 6		# Shift the board right by 6 bits to position 4
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 4
	beq	$t1, $0, ThirdRow	# Branch to ThirdRow if extracted bit is empty
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 5
	andi	$t2, $t0, 3		# Extract the 2 bits stored in position 5
	bne	$t2, $t1,ThirdRow 	# Branch to ThirdRow if extracted bits are not equal
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 6
	andi	$t3, $t0, 3		# Extract the 2 bits stored in position 6
	beq	$t3, $t2, Win		# Branch to Win if extracted bits are equal
	
ThirdRow:	
	add	$t0, $a0, $0		# Load board into $t0
	srl	$t0, $t0, 12		# Shift the board right by 12 bits to position 7
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 7
	beq	$t1, $0, FirstColumn	# Branch to FirstColumn if extracted bit is empty
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 8
	andi	$t2, $t0, 3		# Extract the 2 bits stored in position 8
	bne	$t2, $t1, FirstColumn 	# Branch to FirstColumn if extracted bits are not equal
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 9
	andi	$t3, $t0, 3		# Extract the 2 bits stored in position 9
	beq	$t3, $t2, Win		# Branch to Win if extracted bits are equal		
	
# vertical_check
FirstColumn:
	add	$t0, $a0, $0		# Load board into $t0
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 1
	beq	$t1, $0, SecondColumn	# Branch to SecondColumn if extracted bit is empty
	srl	$t0, $t0, 6		# Shift the board right by 6 bits to position 4
	andi	$t2, $t0, 3		# Extract the 2 bits stored in position 4
	bne	$t2, $t1, SecondColumn	# Branch to SecondColumn if extracted bits are not equal
	srl	$t0, $t0, 6		# Shift the board right by 6 bits to position 7
	andi	$t3, $t0, 3		# Extract the 2 bits stored in position 7
	beq	$t3, $t2, Win		# Branch to Win if extracted bits are equal	
	
SecondColumn:
	add	$t0, $a0, $0		# Load board into $t0
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 2
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 2
	beq	$t1, $0, ThirdColumn	# Branch to ThirdColumn if extracted bit is empty
	srl	$t0, $t0, 6		# Shift the board right by 6 bits to position 5
	andi	$t2, $t0, 3		# Extract the 2 bits stored in position 5
	bne	$t2, $t1,ThirdColumn	# Branch to ThirdColumn if extracted bits are not equal
	srl	$t0, $t0, 6		# Shift the board right by 6 bits to position 8
	andi	$t3, $t0, 3		# Extract the 2 bits stored in position 8
	beq	$t3, $t2, Win		# Branch to Win if extracted bits are equal
	
ThirdColumn:
	add	$t0, $a0, $0		# Load board into $t0
	srl	$t0, $t0, 4		# Shift the board right by 4 bits to position 3
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 3
	beq	$t1, $0, FirstDiagonal	# Branch to FirstDiagonal if extracted bit is empty
	srl	$t0, $t0, 6		# Shift the board right by 6 bits to position 6
	andi	$t2, $t0, 3		# Extract the 2 bits stored in position 6
	bne	$t2, $t1, FirstDiagonal # Branch to FirstDiagonal if extracted bits are not equal
	srl	$t0, $t0, 6		# Shift the board right by 6 bits to position 9
	andi	$t3, $t0, 3		# Extract the 2 bits stored in position 9
	beq	$t3, $t2, Win		# Branch to Win if extracted bits are equal
	
# diagonal_check
# Tiles [1, 5, 9] make FirstDiagonal, [3, 5, 7] make SecondDiagonal. Just do it manually
FirstDiagonal:
	add	$t0, $a0, $0		# Load board into $t0
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 1
	beq	$t1, $0, SecondDiagonal	# Branch to SecondDiagonal if extracted bit is empty
	srl	$t0, $t0, 8		# Shift the board right by 8 bits to position 5
	andi	$t2, $t0, 3		# Extract the 2 bits stored in position 5
	bne	$t2, $t1, SecondDiagonal# Branch to SecondDiagonal if extracted bits are not equal
	srl	$t0, $t0, 8		# Shift the board right by 8 bits to position 9
	andi	$t3, $t0, 3		# Extract the 2 bits stored in position 9
	beq	$t3, $t2, Win		# Branch to Win if extracted bits are equal

SecondDiagonal:
	add	$t0, $a0, $0		# Load board into $t0
	srl	$t0, $t0, 4		# Shift the board right by 4 bits to position 3
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 3
	beq	$t1, $0, NoWin		# Branch to NoWin if extracted bit is empty
	srl	$t0, $t0, 4		# Shift the board right by 4 bits to position 5
	andi	$t2, $t0, 3		# Extract the 2 bits stored in position 5
	bne	$t2, $t1, TieCheck	# Branch to TieCheck if extracted bits are not equal
	srl	$t0, $t0, 4		# Shift the board right by 4 bits to position 7
	andi	$t3, $t0, 3		# Extract the 2 bits stored in position 7
	beq	$t3, $t2, Win		# Branch to Win if extracted bits are equal

# tie_check
TieCheck:
	addi	$t0, $a0, 0		# Load board into $t0
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 1
	beq	$t1, $0, NoWin		# Branch to NoWin if extracted bit is empty
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 2
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 2
	beq	$t1, $0, NoWin		# Branch to NoWin if extracted bit is empty
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 3
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 3
	beq	$t1, $0, NoWin		# Branch to NoWin if extracted bit is empty
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 4
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 4
	beq	$t1, $0, NoWin		# Branch to NoWin if extracted bit is empty
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 5
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 5
	beq	$t1, $0, NoWin		# Branch to NoWin if extracted bit is empty
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 6
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 6
	beq	$t1, $0, NoWin		# Branch to NoWin if extracted bit is empty
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 7
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 7
	beq	$t1, $0, NoWin		# Branch to NoWin if extracted bit is empty
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 8
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 8
	beq	$t1, $0, NoWin		# Branch to NoWin if extracted bit is empty
	srl	$t0, $t0, 2		# Shift the board right by 2 bits to position 9
	andi	$t1, $t0, 3		# Extract the 2 bits stored in position 9
	beq	$t1, $0, NoWin		# Branch to NoWin if extracted bit is empty
	addi	$v0, $0, 3 		# If All Tiles are filled and no one won, it is a Tie (set $v0 to 3)
	jr	$ra			# return to minimax

NoWin:
	addi	$v0, $0, 0		# If any Tile is empty, return No Win (set $v0 to 0)
	jr	$ra			# return to minimax

Win:
	slti	$t3, $t3, 2		# Set $t3 to 1 if its 01 (Human won)
	beq	$t3, $0, ComputerWin	# Branch to ComputerWin if $t3 is 0
# HumanWin
	addi	$v0, $0, 1		# Human has won (set $v0 to 1)
	jr	$ra			# return to Minimax

ComputerWin:
	addi	$v0, $0, 2		# Computer has won (set $v0 to 2)
	jr	$ra			# return to Minimax

# end of check_win_tie

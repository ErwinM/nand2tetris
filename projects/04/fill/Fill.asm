// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input.
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel. When no key is pressed, the
// program clears the screen, i.e. writes "white" in every pixel.

// Put your code here.

// KBD = keyboard and SCREEN = screen


(MAINLOOP)
  @SCREEN
  D=A
  @SCREEN_POINTER
  M=D       // reset screen pointer

  @8192
  D=A
  @SCREEN_SIZE
  M=D       // reset the size counter

  @KBD      // check if key is pressed
  D=M
  @NOPRESS
  D;JEQ
            // ---- key is pressed
  D=-1      // set color
  @color
  M=D
  @FILL_LOOP
  0;JMP     // and call fill subroutine

(NO_PRESS)
  D=0
  @color    // set color
  M=D
  @FILL_LOOP
  0;JMP

(FILL_LOOP)
  @color
  D=M
  @SCREEN_POINTER
  A=M
  M=D         // writes black pixel

  @SCREEN_POINTER
  M=M+1       // decrease the pointer

  @SCREEN_SIZE
  M=M-1
  D=M
  @MAINLOOP
  D;JEQ       // check if entire screen has been cleared
  @FILL_LOOP  // if so jump back into main loop
  0;JMP       // otherwise jump back to fill loop
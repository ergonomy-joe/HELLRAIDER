# HELLRAIDER

Hello retro-programmers-folks !
Does anybody remember the game HELLRAIDER, from the late 80s ?
The intro to the Atari ST version had a killer intro music.
I ran into the MS-DOS version recently, and didn't even know, until then, that it existed.

If you plan to play the game in DosBox, you should configure it in EGA mode, or else, you may have some visual glitches.
I explains the controls in this thread:
https://twitter.com/ergonomy_joe/status/1702528215909302359

I wasreally surprised to see a game, designed for the EGA, with a multi-directionnal scrolling, a few monthes (years?) before "COMMANDER KEEN". So I decided to disassemble it to understand the code.
This repositery is the result of this work. The RAIDER.EXE executable in assembly source, ready to be built.

The DOIT.BAT batch files shows you the necessary tasks to create the exe. You may have to edit it a little to fit your own configuration.
I use "Microsoft Macro Assembler version 5.1" and Microsoft's "Linker version 3.65".

I tried to comment and find good function/variable names, as much as I could, but there are some part of the code, that are still "as is". Sorry about that.

All asm files, execpt RAIDER.ASM, contain raw graphic data: sprites, or bitmaps. I'm pretty sure they must have been generated by some tool/converter. Same for all the "s_sprite" data.

I hope you have a lot of fun going through the code

ergonomy_joe 2023/09/21

# Curr
https://www.computerenhance.com/p/table-of-contents
- Introduction: Waste

# Introduction: Five Multipliers
1st: Waste: CPU doing a lot more instructions that are not part of the core logic. Examples include cleanup code and interpreter overhead.
2nd: IPC: 

# Part1: 8086 ASM
## Code
~/Software/zig/0.15.1/zig build run -- upstream/perfaware/part1/listing_0037_single_register_mov
~/Software/zig/0.15.1/zig build test

~/Software/zig/0.15.1/zig build run -- upstream/perfaware/part1/listing_0037_single_register_mov > result.asm
nasm result.asm
diff upstream/perfaware/part1/listing_0037_single_register_mov result

zig build run -- upstream/perfaware/part1/listing_0038_many_register_mov > result.asm && diff upstream/perfaware/part1/listing_0038_many_register_mov.asm result.asm

## Doc
https://edge.edx.org/c4x/BITSPilani/EEE231/asset/8086_family_Users_Manual_1_.pdf
- P.160 Decoding
    
- 16-bit Registers. Memory-to-Register Movement.
    => Register names have 16-bit (AX), high-8-bit (AH) and low-8-bit variants (AL).
    MOV AX, BX => 16-bit, MOV AL, BL
- Instruction Decode: From byte encoding to actual work.
- Mnemonic = Human friendly name: MOV AX,BX = Move (Operand) from Bx (Source) to Ax (Destination).
- 8-bit Encoding: Opcode (6) + D-Flag () + W-Flag ()
- 8-bit Opcode Parameter: MOD-Field (2), REG-Field (3), RM (3)


# TODO
## Decoder cleanup
- Decoder.zig

# Curr
https://www.computerenhance.com/p/table-of-contents
- Decoding Multiple INstructions and Suffixes

# Introduction: Five Multipliers
1st: Waste: CPU doing a lot more instructions that are not part of the core logic. Examples include cleanup code and interpreter overhead.
2nd: IPC: 

# Part1: 8086 ASM
## Code
https://github.com/cmuratori/computer_enhance

~/Software/zig/0.15.1/zig build run -- upstream/perfaware/part1/listing_0037_single_register_mov
~/Software/zig/0.15.1/zig build test

~/Software/zig/0.15.1/zig build run -- upstream/perfaware/part1/listing_0037_single_register_mov > result.asm
nasm result.asm
diff upstream/perfaware/part1/listing_0037_single_register_mov result

testing:
zig build run -- upstream/perfaware/part1/listing_0039_more_movs > result.asm && nasm result.asm && diff result upstream/perfaware/part1/listing_0039_more_movs

## Taks:
(second is always the challenge version).
0037-0038: mov
0039-0040: mov variants.
0041-0042: add_sub_cmp_jnz: p.165-p.166

## Doc
https://edge.edx.org/c4x/BITSPilani/EEE231/asset/8086_family_Users_Manual_1_.pdf
- P.160 Decoding.
    
- 16-bit Registers. Memory-to-Register Movement.
    => Register names have 16-bit (AX), high-8-bit (AH) and low-8-bit variants (AL).
    MOV AX, BX => 16-bit, MOV AL, BL
- Instruction Decode: From byte encoding to actual work.
- Mnemonic = Human friendly name: MOV AX,BX = Move (Operand) from Bx (Source) to Ax (Destination).
- 8-bit Encoding: Opcode (6) + D-Flag (destination) + W-Flag (wide (16-bit))
- 8-bit Opcode Parameter: MOD-Field (2), REG-Field (3), RM-Field (3)
- 16-bit Displacement: Optional for memory data.
- 86 architecture: variable length: Each byte can tell us if there is one more byte after that for the same instruction.
- memory operation: mov bx, [address]
- x86 is little endian.
- effective address calculation: mov bx, [bp + 75] => displacement => defined by MOD-field
- MOD-field: do we have 1-byte or 2-byte displacement? means we have more bytes coming in.
- destination flag and memory: 1 == load (register is destination), 0 == store (register is source). 
- RM-Field: Encodes type of equation of effective address calculation.
    - (bx)+(si), (bx)+(di), (bp)+(si), (bp)+(di), (si), (di), (bp), (bx)  
    - with the MOD field you add d8 or d16 to it.
    - MOD == 0 and RM = 110 => 2 byte immediate direct address.
- Basic pattern for a lot of instructions:
    [Opcode DW][MOD REG R/M] DISP
    [Opcode W][MOD 000 R/M] IMM
    => Because of this you can bake in memory access into the operation (e.g. ADD with memory access).
- Arithmetic Commands:
    - Immediate mode version have [MOD XXX R/M] in the second byte.
    - the XXX is the actual arithmetic operation to do.
    - This means we have the same opcode for different arithmetic operations.
    - The same bit-pattern is used as the last 3 bits of the operand.
- Conditional Jump:
    - First byte: Patterns states which kind of jump (JNZ).
    - Second byte is 8-bit displacement.

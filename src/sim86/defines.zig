const std = @import("std");

pub const Operation = enum {
    none, mov, push, pop,
    xchg, in, out, xlat,
    lea, lds, les, lahf,
    sahf, pushf, popf, add,
    adc, inc, aaa, daa,
    sub, sbb, dec, neg,
    cmp, aas, das, mul,
    imul, aam, div, idiv,
    aad, cbw, cwd, not,
    shl, shr, sar, rol,
    ror, rcl, rcr, @"and",
    @"test", @"or", xor, rep,
    movs, cmps, scas, lods,
    stos, call, jmp, ret,
    je, jl, jle, jb,
    jbe, jp, jo, js,
    jne, jnl, jg, jnb,
    ja, jnp, jno, jns,
    loop, loopz, loopnz, jcxz,
    int, int3, into, iret,
    clc, cmc, stc, cld,
    std, cli, sti, hlt,
    wait, esc, lock, segment,
};

const RegisterFile = packed union {
    r16: packed struct {
        ax: u16,
        cx: u16,
        dx: u16,
        bx: u16,
        sp: u16, // stack pointer
        bp: u16, // base pointer
        si: u16, // source index
        di: u16, // dest index
    },
    r8: packed struct {
        al: u8, ah: u8,
        cl: u8, ch: u8,
        dl: u8, dh: u8,
        bl: u8, bh: u8,
        spl: u8, sph: u8, // invalid
        bpl: u8, bph: u8, // invalid
        sil: u8, sih: u8, // invalid
        dil: u8, dih: u8, // invalid
    },
};

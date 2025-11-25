const std = @import("std");

pub const Operation = enum {
    none,
    mov,
    lock,
    rep,
    segment,
    xchg,
};

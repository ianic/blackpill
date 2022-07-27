const micro = @import("microzig");
const regs = micro.chip.registers;

pub const interrupts = struct {
    pub fn EXTI0() void {
        key_pressed = true;
        regs.EXTI.PR.modify(.{ .PR0 = 1 });
    }
};

const short = 100;
const long = 1000;

var key_pressed = false;

const led_pin = micro.Pin("PC13");
const led = micro.Gpio(led_pin, .{
    .mode = .output,
    .initial_state = .high,
});

const key_pin = micro.Pin("PA0");
const key = micro.Gpio(key_pin, .{
    .mode = .input,
    .initial_state = .high,
});

fn blink(times: u32) void {
    var i: u32 = 0;
    while (i < times) : (i += 1) {
        led.setToLow();
        sleep(short);
        led.setToHigh();
        sleep(short);
    }
}

pub fn main() void {
    systemInit();
    setup();

    var counter: u32 = 1;
    while (true) {
        if (key_pressed) {
            counter += 1;
            key_pressed = false;
        }
        blink(counter);
        sleep(long);
    }
}

fn sleep(ms: u32) void {
    const loop_ops = 5; // estimate number of instruction per loop
    var ticks: u32 = clock_frequencies.cpu / 1000 * ms / loop_ops;
    while (ticks > 0) : (ticks -= 1) {
        asm volatile ("nop");
    }
}

//Default clock frequencies after reset
// prescalers are set in systemInit
pub const clock_frequencies = .{
    .cpu = 48_000_000,
    .ahb = 48_000_000 / 1, // .HPRE
    .apb1 = 48_000_000 / 4, // .PPRE1
    .apb2 = 48_000_000 / 2, // .PPRE2
};

fn setup() void {
    led.init();
    key.init();

    // PA0 interupt enabling
    regs.SYSCFG.EXTICR1.modify(.{ .EXTI0 = 1 });
    regs.EXTI.RTSR.modify(.{ .TR0 = 1 });
    regs.EXTI.IMR.modify(.{ .MR0 = 1 });
    regs.NVIC.ISER0.modify(.{ .SETENA = 0x40 });
}

fn systemInit() void {
    // Enable FPU coprocessor
    // WARN: currently not supported in qemu, comment if testing it there
    regs.FPU_CPACR.CPACR.modify(.{ .CP = 0b11 });

    // Enable HSI
    regs.RCC.CR.modify(.{ .HSION = 1 });

    // Wait for HSI ready
    while (regs.RCC.CR.read().HSIRDY != 1) {}

    // Select HSI as clock source
    regs.RCC.CFGR.modify(.{ .SW0 = 0, .SW1 = 0 });

    // Enable external high-speed oscillator (HSE)
    regs.RCC.CR.modify(.{ .HSEON = 1 });

    // Wait for HSE ready
    while (regs.RCC.CR.read().HSERDY != 1) {}

    // Set prescalers for 48 MHz: HPRE = 0, PPRE1 = DIV_4, PPRE2 = DIV_2
    regs.RCC.CFGR.modify(.{ .HPRE = 0, .PPRE1 = 0b101, .PPRE2 = 0b100 });

    //setPllCfgr(25, 384, 4, 8); // 96 Mhz
    setPllCfgr(25, 384, 8, 8); // 48 Mhz
    //setPllCfgr(50, 384, 8, 4); // 24 Mhz

    // Disable HSI
    regs.RCC.CR.modify(.{ .HSION = 0 });
}

// Fv = source * n / m
// Fsystem = Fv / p
// Fusb = Fv / q  must be e.q. 48Mhz
//
// m 2..63
// n 50..432
// p 2,4,6,8
// q 2..15
//
// hse source = 25Mhz
// Fsystem max = 100Mhz
fn setPllCfgr(comptime m: u16, comptime n: u16, comptime p: u16, comptime q: u16) void {
    if (!((m >= 2 and m <= 63) and
        (n >= 50 and n <= 432) and
        (p == 2 or p == 4 or p == 6 or p == 8) and
        (q >= 2 and q <= 15)))
    {
        @compileError("wrong RCC PLL configuration register values");
    }

    // assuming 25 MHz of external clock
    //@compileLog("setting system clock to [MHz] ", 25 * n / m / p);
    //@compileLog("USB clock to [MHz] ", 25 * n / m / q);

    // Disable PLL before changing its configuration
    regs.RCC.CR.modify(.{ .PLLON = 0 });

    regs.RCC.PLLCFGR.modify(.{
        .PLLSRC = 1,
        // PLLM
        .PLLM0 = bitOf(m, 0),
        .PLLM1 = bitOf(m, 1),
        .PLLM2 = bitOf(m, 2),
        .PLLM3 = bitOf(m, 3),
        .PLLM4 = bitOf(m, 4),
        .PLLM5 = bitOf(m, 5),
        // PLLN
        .PLLN0 = bitOf(n, 0),
        .PLLN1 = bitOf(n, 1),
        .PLLN2 = bitOf(n, 2),
        .PLLN3 = bitOf(n, 3),
        .PLLN4 = bitOf(n, 4),
        .PLLN5 = bitOf(n, 5),
        .PLLN6 = bitOf(n, 6),
        .PLLN7 = bitOf(n, 7),
        .PLLN8 = bitOf(n, 8),
        // PLLP
        .PLLP0 = if (p == 4 or p == 8) 1 else 0,
        .PLLP1 = if (p == 6 or p == 8) 1 else 0,
        // PLLQ
        .PLLQ0 = bitOf(q, 0),
        .PLLQ1 = bitOf(q, 1),
        .PLLQ2 = bitOf(q, 2),
        .PLLQ3 = bitOf(q, 3),
    });
    // Enable PLL
    regs.RCC.CR.modify(.{ .PLLON = 1 });

    // Wait for PLL ready
    while (regs.RCC.CR.read().PLLRDY != 1) {}

    // Enable flash data and instruction cache and set flash latency to 5 wait states
    regs.FLASH.ACR.modify(.{ .DCEN = 1, .ICEN = 1, .LATENCY = 5 });

    // // Select PLL as clock source
    regs.RCC.CFGR.modify(.{ .SW1 = 1, .SW0 = 0 });

    // // Wait for PLL selected as clock source
    var cfgr = regs.RCC.CFGR.read();
    while (cfgr.SWS1 != 1 and cfgr.SWS0 != 0) : (cfgr = regs.RCC.CFGR.read()) {}
}

const std = @import("std");
test "is bit set" {
    try std.testing.expectEqual(bitOf(336, 0), 0);
    try std.testing.expectEqual(bitOf(336, 1), 0);
    try std.testing.expectEqual(bitOf(336, 2), 0);
    try std.testing.expectEqual(bitOf(336, 3), 0);
    try std.testing.expectEqual(bitOf(336, 5), 0);
    try std.testing.expectEqual(bitOf(336, 7), 0);

    try std.testing.expectEqual(bitOf(336, 4), 1);
    try std.testing.expectEqual(bitOf(336, 6), 1);
    try std.testing.expectEqual(bitOf(336, 8), 1);
}

fn bitOf(x: u16, index: u4) u1 {
    const mask = @as(u16, 1) << index;
    return if (x & mask == mask) 1 else 0;
}

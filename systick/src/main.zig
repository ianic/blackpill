const micro = @import("microzig");
const chip = micro.chip;
const regs = chip.registers;

pub const interrupts = struct {
    pub fn SysTick() void {
        ticks += 1;
        if (ticks % 1000 == 0) {
            counter += 1;
        }
    }

    pub fn EXTI0() void {
        counter = 0;
        regs.EXTI.PR.modify(.{ .PR0 = 1 });
    }
};

var ticks: u32 = 0;
var counter: u32 = 1;

pub fn main() void {
    chip.init();
    chip.systick(10);

    while (true) {
        chip.led.blink(counter);
        chip.delay.long();
    }
}

// access to register definitions
const regs = @import("microzig").chip.registers;

pub fn main() !void {
    // Enable GPIOD port
    regs.RCC.AHB1ENR.modify(.{ .GPIOCEN = 1 }); // C is from PC13

    // Set pin 13 mode to general purpose output
    regs.GPIOC.MODER.modify(.{ .MODER13 = 0b01 }); // 13 is from PC13

    // Set pin 13
    regs.GPIOC.BSRR.modify(.{ .BS13 = 1 });

    while (true) {
        // Read the LED state
        var leds_state = regs.GPIOC.ODR.read();
        // Set the LED output to the negation of the currrent output
        regs.GPIOC.ODR.modify(.{
            .ODR13 = ~leds_state.ODR13,
        });
        micro.debug.busySleep(100_000);

        // // most trivial example, without read:
        // regs.GPIOC.BSRR.modify(.{ .BR13 = 1 });
        // micro.debug.busySleep(100_000);
        // regs.GPIOC.BSRR.modify(.{ .BS13 = 1 });
        // micro.debug.busySleep(100_000);

        // // sleep with nop
        // var i: u32 = 0;
        // while (i < 1000000) {
        //     asm volatile ("nop");
        //     i += 1;
        // }
    }
}

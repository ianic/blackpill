const std = @import("std");
const micro = @import("microzig");
const chip = micro.chip;
const regs = chip.registers;

pub const interrupts = struct {
    pub fn SysTick() void {}

    pub fn EXTI0() void {
        regs.EXTI.PR.modify(.{ .PR0 = 1 });
    }
};

pub fn main() void {
    chip.init();
    chip.systick(1);

    pwm_init();
    while (true) {}
}

fn pwm_init() void {
    // enable output pin for the timer
    // PB8, pin B port 8 to alternate function T10_CH1
    regs.RCC.AHB1ENR.modify(.{ .GPIOBEN = 1 }); // enable gpio port B
    regs.GPIOB.MODER.modify(.{ .MODER8 = 0b10 }); // set pin 8 to alternate function mode
    regs.GPIOB.AFRH.modify(.{ .AFRH8 = 0b0011 }); // use AF3 alternate function 3 = TIM10_CH1

    // general timer
    regs.RCC.APB2ENR.modify(.{ .TIM10EN = 1 }); // enable Timer
    regs.TIM10.PSC.modify(48); // set the prescaler
    regs.TIM10.ARR.modify(1000); // set upper limit of the count

    // configure timer 10 channel 1
    regs.TIM10.CCMR1_Output.modify(.{ .OC1M = 0b110, .OC1PE = 1 }); // output compare mode, and enable
    regs.TIM10.CCER.modify(.{ .CC1E = 1 }); // enable output
    regs.TIM10.CCR1.modify(50); // upper limit of count

    // enable the counter
    regs.TIM10.CR1.modify(.{ .CEN = 1 });
}

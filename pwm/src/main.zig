const std = @import("std");
const micro = @import("microzig");
const chip = micro.chip;
const regs = chip.registers;

var ticks: u32 = 0;

pub const interrupts = struct {
    pub fn SysTick() void {
        tick();
    }

    pub fn EXTI0() void {
        //tim_overflows += 1;
        regs.EXTI.PR.modify(.{ .PR0 = 1 });
        //regs.TIM9.SR.modify(.{ .TIF = 0 });
    }

    pub fn TIM1_UP_TIM10() void {
        // Check and clear status register UIF = Update interrupt pending
        if (regs.TIM10.SR.read().UIF == 1) {
            regs.TIM10.SR.modify(.{ .UIF = 0 });
            tim_overflows += 1;
        }
    }
};

const Task = struct {
    frame: anyframe = undefined,
    resume_at: u32 = 0,

    const Self = @This();

    pub fn schedule(self: *Self, frame: anyframe, after: u32) void {
        self.frame = frame;
        self.resume_at = ticks + after;
    }

    pub fn runnable(self: *Self) bool {
        return !(self.frame == undefined or
            self.resume_at == 0 or
            self.resume_at > ticks);
    }

    pub fn try_run(self: *Self) void {
        if (self.frame == undefined or
            self.resume_at == 0 or
            self.resume_at > ticks)
        {
            return;
        }

        var fr = self.frame;
        self.resume_at = 0;
        self.frame = undefined;
        resume fr;
    }

    pub fn sleep(self: *Self, ms: u32) void {
        suspend {
            self.resume_at = ticks + ms;
            self.frame = @frame();
        }
    }
};

var tim_counter: u16 = 0;
var tim_overflows: u16 = 0;

pub fn main() void {
    chip.init();
    chip.systick(1);
    chip.led.off();

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

    // to enable timer interrupt:
    regs.TIM10.DIER.modify(.{ .UIE = 1 }); // update interrupt enable
    regs.NVIC.ISER0.modify(.{ .SETENA = 1 << 25 }); // enable IRQn 25 in cpu nvic

    nosuspend start_tasks();

    while (true) {
        // Read current counter value
        tim_counter = regs.TIM10.CNT.read();
        asm volatile ("nop");
    }
}

var tasks: [2]*Task = undefined;

fn start_tasks() void {
    var t1 = Task{};
    tasks[0] = &t1;
    var fr1 = async blink_loop(&t1, 1000);

    var t2 = Task{};
    tasks[1] = &t2;
    var fr2 = async uart_loop(&t2);

    await fr1;
    await fr2;
}

fn tick() void {
    ticks += 1;
    for (tasks) |task| {
        if (task == undefined) {
            continue;
        }
        task.try_run();
    }
}

fn blink_loop(task: *Task, sleep: u32) void {
    chip.led.off();
    while (true) {
        task.sleep(sleep);
        chip.led.on();
        task.sleep(50);
        chip.led.off();
    }
}

fn uart_loop(task: *Task) void {
    const uart_idx = 2;
    const pins = .{ .tx = micro.Pin("PA2"), .rx = micro.Pin("PA3") };

    var uart = micro.Uart(uart_idx, pins).init(.{
        .baud_rate = 9600,
        .stop_bits = .one,
        .parity = null,
        .data_bits = .eight,
    }) catch {
        return;
    };

    var out = uart.writer();

    var buf: [128]u8 = undefined;
    while (true) {
        const s = std.fmt.bufPrint(buf[0..], "tim9 counter: {d} overflows: {d} \r\n", .{ tim_counter, tim_overflows }) catch buf[0..0];
        try out.writeAll(s);
        task.sleep(1000);
    }
}

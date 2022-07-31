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

    pub fn TIM1_BRK_TIM9() void {
        // Check and clear status register UIF = Update interrupt pending
        if (regs.TIM9.SR.read().UIF == 1) {
            regs.TIM9.SR.modify(.{ .UIF = 0 });
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

    // To enable timmer in pooling mode:
    // Enable Timer 1
    regs.RCC.APB2ENR.modify(.{ .TIM9EN = 1 });
    // Set the prescaler
    regs.TIM9.PSC.modify(48000);
    // Enable the counter
    regs.TIM9.CR1.modify(.{ .CEN = 1 });
    // Set upper limit of the count
    regs.TIM9.ARR.modify(5000);
    // Counter used as upcounter/downcounter (not supported for TIM9)
    //regs.TIM9.CR1.modify(.{ .DIR = 0 });

    // To enable timmer interrupt:
    // Update interrupt enable
    regs.TIM9.DIER.modify(.{ .UIE = 1 });
    // Enable IRQ TIM1_BRK_TIM9_IRQn = 24
    regs.NVIC.ISER0.modify(.{ .SETENA = 0x1_000_000 });

    nosuspend start_tasks();

    while (true) {
        // Read current counter value
        tim_counter = regs.TIM9.CNT.read();
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

fn blinkError(err: micro.uart.InitError) void {
    var blinks: u3 =
        switch (err) {
        error.UnsupportedBaudRate => 1,
        error.UnsupportedParity => 2,
        error.UnsupportedStopBitCount => 3,
        error.UnsupportedWordSize => 4,
    };

    while (blinks > 0) : (blinks -= 1) {
        chip.led.on();
        micro.debug.busySleep(1_000_000);
        chip.led.off();
        micro.debug.busySleep(1_000_000);
    }
}

const std = @import("std");

fn loop() void {
    var fr = async fn2();
    await fr;
}

fn fn2() void {
    var i: u32 = 0;
    while (true) : (i += 1) {
        suspend {
            std.time.sleep(std.time.ns_per_ms * 100);
            resume @frame();
        }
        std.debug.print("in fn2 {d}\n", .{i});
        if (i == 10) {
            return;
        }
    }
}

test "ne bi trebalo nikada zavrsiti" {
    //nosuspend await (async loop());
    nosuspend loop();
}

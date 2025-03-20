const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    // Добавление зависимости udp_uring
    const udp_uring_dep = b.dependency("udp", .{
        .target = target,
    });
    const shock_mod = b.dependency("shock", .{}).artifact("shock");

    const exe = b.addExecutable(.{
        .name = "shock-udp",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const udp_artifact = udp_uring_dep.artifact("udp");

    // Добавляем модуль как зависимость к исполняемому файлу
    exe.root_module.addImport("udp", udp_artifact.root_module);
    exe.root_module.addImport("shock", shock_mod.root_module);

    // Для более новых версий Zig (0.11.0+), используйте следующий синтаксис вместо:
    // exe.root_module.addImport("udp", udp_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run shock");
    run_step.dependOn(&run_cmd.step);
}

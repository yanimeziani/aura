const std = @import("std");
const flow = @import("flow.zig");
const executor = @import("executor.zig");
const Allocator = std.mem.Allocator;

pub const Job = struct {
    workflow_path: []const u8,
    input: std.json.Value,
    retries: u32 = 0,
    max_retries: u32 = 3,
    next_retry_at: i64 = 0,
};

pub const WorkerPool = struct {
    allocator: Allocator,
    jobs: std.ArrayList(Job),
    mutex: std.Thread.Mutex,
    cond: std.Thread.Condition,
    threads: []std.Thread,
    running: bool,
    dlq_path: []const u8,

    pub fn init(allocator: Allocator, thread_count: usize, dlq_path: []const u8) !*WorkerPool {
        const self = try allocator.create(WorkerPool);
        self.* = .{
            .allocator = allocator,
            .jobs = std.ArrayList(Job).init(allocator),
            .mutex = .{},
            .cond = .{},
            .threads = try allocator.alloc(std.Thread, thread_count),
            .running = true,
            .dlq_path = try allocator.dupe(u8, dlq_path),
        };

        for (0..thread_count) |i| {
            self.threads[i] = try std.Thread.spawn(.{}, workerLoop, .{self});
        }

        return self;
    }

    pub fn deinit(self: *WorkerPool) void {
        self.mutex.lock();
        self.running = false;
        self.mutex.unlock();
        self.cond.broadcast();

        for (self.threads) |thread| {
            thread.join();
        }

        self.allocator.free(self.threads);
        self.allocator.free(self.dlq_path);
        // Clean up jobs (deep free if needed)
        self.jobs.deinit();
        self.allocator.destroy(self);
    }

    pub fn enqueue(self: *WorkerPool, job: Job) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.jobs.append(job);
        self.cond.signal();
    }
};

fn workerLoop(pool: *WorkerPool) void {
    while (true) {
        pool.mutex.lock();
        while (pool.running and pool.jobs.items.len == 0) {
            pool.cond.wait(&pool.mutex);
        }

        if (!pool.running) {
            pool.mutex.unlock();
            return;
        }

        // Find a job that is ready for retry
        var job_idx: ?usize = null;
        const now = std.time.timestamp();
        for (pool.jobs.items, 0..) |job, i| {
            if (job.next_retry_at <= now) {
                job_idx = i;
                break;
            }
        }

        if (job_idx == null) {
            pool.mutex.unlock();
            std.Thread.sleep(100 * std.time.ns_per_ms);
            continue;
        }

        const job = pool.jobs.orderedRemove(job_idx.?);
        pool.mutex.unlock();

        processJob(pool, job) catch |err| {
            std.debug.print("Job processing failed: {}\n", .{err});
            handleJobFailure(pool, job) catch |e| {
                std.debug.print("Failed to handle job failure: {}\n", .{e});
            };
        };
    }
}

fn processJob(pool: *WorkerPool, job: Job) !void {
    const file_content = try std.fs.cwd().readFileAlloc(pool.allocator, job.workflow_path, 10 * 1024 * 1024);
    defer pool.allocator.free(file_content);

    const wf = try flow.Workflow.parse(pool.allocator, file_content);
    defer wf.deinit();

    const ctx = try executor.ExecutionContext.init(pool.allocator);
    defer ctx.deinit();

    try ctx.set("input", job.input);

    try executor.execute(wf, ctx);
}

fn handleJobFailure(pool: *WorkerPool, job: Job) !void {
    var mut_job = job;
    if (mut_job.retries < mut_job.max_retries) {
        mut_job.retries += 1;
        // Exponential backoff: 2, 4, 8 seconds
        const delay = @as(i64, 1) << @intCast(mut_job.retries);
        mut_job.next_retry_at = std.time.timestamp() + delay;
        try pool.enqueue(mut_job);
        std.debug.print("Job scheduled for retry in {}s\n", .{delay});
    } else {
        try moveToDLQ(pool, mut_job);
    }
}

fn moveToDLQ(pool: *WorkerPool, job: Job) !void {
    std.debug.print("Job moved to DLQ: {s}\n", .{job.workflow_path});
    const f = try std.fs.cwd().createFile(pool.dlq_path, .{ .truncate = false });
    defer f.close();
    try f.seekFromEnd(0);
    
    var string = std.ArrayList(u8).init(pool.allocator);
    defer string.deinit();
    
    try std.json.stringify(.{
        .workflow_path = job.workflow_path,
        .input = job.input,
        .failed_at = std.time.timestamp(),
    }, .{}, string.writer());
    try string.append('\n');
    
    try f.writeAll(string.items);
}

const std = @import("std");
const executor = @import("executor.zig");

pub fn parseAndNormalizeStripe(ctx: *executor.ExecutionContext, input: std.json.Value) !void {
    if (input != .object) return error.InvalidStripeEvent;
    
    const event_type = input.object.get("type") orelse return error.MissingType;
    const data = input.object.get("data") orelse return error.MissingData;
    const object = data.object.get("object") orelse return error.MissingObject;
    
    try ctx.set("stripe_event_type", event_type);
    
    if (std.mem.eql(u8, event_type.string, "checkout.session.completed")) {
        const customer_email = object.object.get("customer_details").?.object.get("email").?.string;
        const amount_total = object.object.get("amount_total").?.integer;
        const currency = object.object.get("currency").?.string;
        
        try ctx.set("customer_email", .{ .string = customer_email });
        try ctx.set("amount", .{ .integer = amount_total });
        try ctx.set("currency", .{ .string = currency });
        try ctx.set("status", .{ .string = "paid" });
    }
}

pub const PaymentFulfillmentTemplate = 
    \\{
    \\  "name": "payment-to-fulfillment",
    \\  "nodes": [
    \\    { "id": "start", "type": "trigger", "next": "parse" },
    \\    { "id": "parse", "type": "stripe_parse", "next": "check_paid" },
    \\    {
    \\      "id": "check_paid",
    \\      "type": "condition",
    \\      "config": { "key": "status", "value": "paid" },
    \\      "on_true": "fulfill",
    \\      "on_false": "ignore"
    \\    },
    \\    {
    \\      "id": "fulfill",
    \\      "type": "subprocess",
    \\      "config": { "cmd": "/usr/bin/echo Fulfilling order for customer" },
    \\      "next": "notify"
    \\    },
    \\    {
    \\      "id": "notify",
    \\      "type": "http_request",
    \\      "config": { "url": "http://localhost:9000/notify", "method": "POST" }
    \\    },
    \\    { "id": "ignore", "type": "trigger" }
    \\  ]
    \\}
;

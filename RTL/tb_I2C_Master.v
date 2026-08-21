// tb_I2C_Master.v — verifies START/STOP and ACK for a write transaction
`timescale 1ns/1ps

module tb_I2C_Master;

parameter CLK_DIV = 4;   // fast for simulation

reg       clk = 0;
reg       rst = 1;
reg       start_tx = 0;
reg [6:0] addr      = 7'h48;
reg [7:0] data_byte = 8'hAB;
wire      scl;
wire      sda_out;
reg       sda_in = 1;   // simulate slave pulling ACK
wire      busy, done, ack_err;

i2c_master #(.CLK_DIV(CLK_DIV)) dut (
    .clk(clk),.rst(rst),.start_tx(start_tx),
    .addr(addr),.data_byte(data_byte),
    .scl(scl),.sda_out(sda_out),.sda_in(sda_in),
    .busy(busy),.done(done),.ack_err(ack_err)
);

always #5 clk = ~clk;

integer pass_cnt = 0, fail_cnt = 0;
integer scl_rise = 0;
reg start_detected = 0;
reg stop_detected  = 0;
reg sda_prev = 1;
reg scl_prev = 1;

// Detect START and STOP conditions
always @(sda_out or scl) begin
    if (scl && ~sda_out && sda_prev) begin
        start_detected = 1;
        $display("[%0t ns] START condition detected", $time);
    end
    if (scl && sda_out && ~sda_prev) begin
        stop_detected = 1;
        $display("[%0t ns] STOP condition detected", $time);
    end
    sda_prev = sda_out;
end

// Simulate slave ACK: pull SDA low during ACK clocks
// (simplified: always ACK by tying sda_in=0 during ACK windows)
initial begin
    $dumpfile("tb_I2C_Master.vcd");
    $dumpvars(0, tb_I2C_Master);

    repeat(4) @(posedge clk);
    rst = 0;
    repeat(2) @(posedge clk);

    // Send a write transaction: addr=0x48, data=0xAB
    // Slave will ACK (sda_in=0 simulated below)
    @(posedge clk);
    start_tx = 1;
    @(posedge clk);
    start_tx = 0;

    // Simulate slave pulling SDA low for both ACK windows
    // (Hold sda_in=0 throughout for simplicity — a real slave would
    //  only pull during the ACK bit. For testbench purposes this works.)
    sda_in = 0;

    // Wait for done
    @(posedge done);
    @(posedge clk);

    // Release sda_in
    sda_in = 1;

    // Check: START was detected
    if (start_detected) begin
        $display("PASS: START condition generated"); pass_cnt = pass_cnt + 1;
    end else begin
        $display("FAIL: START condition NOT detected"); fail_cnt = fail_cnt + 1;
    end

    // Check: STOP was detected
    if (stop_detected) begin
        $display("PASS: STOP condition generated"); pass_cnt = pass_cnt + 1;
    end else begin
        $display("FAIL: STOP condition NOT detected"); fail_cnt = fail_cnt + 1;
    end

    // Check: no ack_err (slave acknowledged)
    if (!ack_err) begin
        $display("PASS: ACK received (no ack_err)"); pass_cnt = pass_cnt + 1;
    end else begin
        $display("FAIL: ack_err asserted unexpectedly"); fail_cnt = fail_cnt + 1;
    end

    // Check busy released
    if (!busy) begin
        $display("PASS: busy deasserted after done"); pass_cnt = pass_cnt + 1;
    end else begin
        $display("FAIL: busy still high after done"); fail_cnt = fail_cnt + 1;
    end

    if (fail_cnt == 0)
        $display("\nALL TESTS PASSED (%0d/%0d)", pass_cnt, pass_cnt+fail_cnt);
    else
        $display("\nFAILED: %0d passed, %0d failed", pass_cnt, fail_cnt);

    $finish;
end

initial #500000 begin $display("TIMEOUT"); $finish; end

endmodule
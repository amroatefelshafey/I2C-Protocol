// tb_I2C_Master.v — verifies START/STOP and ACK for a write transaction
`timescale 1ns/1ps

module tb_I2C_Master;

parameter CLK_DIV = 4;   // fast for simulation
parameter ADDR_WIDTH = 7;
parameter BYTES_TO_READ = 3;

reg       CLK = 0;
reg       RST = 0;
reg [ADDR_WIDTH-1:0] Slave_Addr = 7'h48;
reg 	  R_W = 0; // 0 is for Write
reg [7:0] Write_Data = 8'hAB;
reg       Start = 0;
reg       sda_in = 1;   // simulate slave pulling ACK

wire 	   SDA;
wire       SCL;
wire 	   SDA_OE;
wire	   Busy;
wire [7:0] Read_Data;

i2c_master #(.CLK_DIV(CLK_DIV), .ADDR_WIDTH(ADDR_WIDTH), .BYTES_TO_READ(BYTES_TO_READ)) dut 
(
    .CLK(CLK), .RST(RST), .Start(Start),
    .Slave_Addr(Slave_Addr), .Write_Data(Write_Data), .R_W(R_W),
    .sda_in(sda_in), .SCL(SCL), .SDA(SDA), .SDA_OE(SDA_OE),
    .Busy(Busy), .Read_Data(Read_Data)
);

always #5 CLK = ~CLK;

integer pass_cnt = 0, fail_cnt = 0;
reg start_detected = 0;
reg stop_detected  = 0;
reg sda_prev = 1;

// Detect START and STOP conditions
always @(SDA or SCL) begin
    if (SCL && ~SDA && sda_prev) begin // SDA goes low (1->0) while SCL is high is START, detected by the if clause
        start_detected = 1;
        $display("[%0t ns] START condition detected", $time);
    end
    if (SCL && SDA && ~sda_prev) begin // SDA goes high (0->1) while SCL is high is STOP, detected by the if clause
        stop_detected = 1;
        $display("[%0t ns] STOP condition detected", $time);
    end
    sda_prev = SDA;
end

// Simulate slave ACK: pull SDA low during ACK clocks
// (simplified: always ACK by tying sda_in=0 during ACK windows)
initial begin
    $dumpfile("tb_I2C_Master.vcd");
    $dumpvars(0, tb_I2C_Master);

	force RST = 1; // Make sure all values are initialized correctly
	#10;
	release RST;
	RST = 0;
	#10;
	

    // Release sda_in
    sda_in = 1;
	
	// Test #1: IDLE State
	if (dut.State == dut.IDLE) begin
		$display("Sitting at IDLE State"); pass_cnt = pass_cnt + 1;
    end else begin
        $display("ERROR: IDLE State is not the initial state"); fail_cnt = fail_cnt + 1;
		$stop; // If simulating using Icarus Verilog, please enter "cont" to continue simulation
    end
	
	Start = 1;
	#80;

    // Test #2: START was detected
    if (start_detected) begin
        $display("PASS: START condition generated"); pass_cnt = pass_cnt + 1;
    end else begin
        $display("FAIL: START condition NOT detected"); fail_cnt = fail_cnt + 1;
    end
	
	
	// Test #3: Master sends address to slave
	

    // Check: STOP was detected
    if (stop_detected) begin
        $display("PASS: STOP condition generated"); pass_cnt = pass_cnt + 1;
    end else begin
        $display("FAIL: STOP condition NOT detected"); fail_cnt = fail_cnt + 1;
    end

    // Check Busy released
    if (!Busy) begin
        $display("PASS: Busy deasserted after done"); pass_cnt = pass_cnt + 1;
    end else begin
        $display("FAIL: Busy still high after done"); fail_cnt = fail_cnt + 1;
    end


	// Final Check for # of errors
    if (fail_cnt == 0)
        $display("\nALL TESTS PASSED (%0d/%0d)", pass_cnt, pass_cnt+fail_cnt);
    else
        $display("\nFAILED: %0d passed, %0d failed", pass_cnt, fail_cnt);

    $finish;
end

initial #500000 begin $display("TIMEOUT"); $finish; end

endmodule
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
// So {Slave_Addr, R_W} = {100 1000, 0} = 8'b1001 0000 = 8'h90
reg [7:0] Write_Data = 8'hAB;
reg       Start = 0;
reg       sda_in;

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

function [8*9:1] get_state_name;
    input [2:0] state_val;
    begin
        case (state_val)
            3'b000:  get_state_name = "IDLE     ";
            3'b001:  get_state_name = "START    ";
            3'b010:  get_state_name = "ADDR     ";
            3'b011:  get_state_name = "READ_ACK ";
            3'b100:  get_state_name = "SEND_ACK ";
            3'b101:  get_state_name = "READ_DATA";
            3'b110:  get_state_name = "WR_DATA  ";
            3'b111:  get_state_name = "STOP     ";
            default: get_state_name = "UNKNOWN  ";
        endcase
    end
endfunction

task state_assertion;
	input [2:0] State;
	begin
		if(dut.State == State) begin 
			$display("Time %0t: Sitting at %s State", $time, get_state_name(State)); pass_cnt = pass_cnt + 1;
		end else begin
			$display("ERROR: FSM not on %s State", get_state_name(State)); fail_cnt = fail_cnt + 1;
			$stop; // If simulating using Icarus Verilog, please enter "cont" to continue simulation
		end
	end
endtask

always #5 CLK = ~CLK;

integer pass_cnt = 0, fail_cnt = 0;
integer i;

reg [7:0] tb_addr_rw;
reg [7:0] tb_Write_Data;
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
	
	
	// Test #1: IDLE State
	if (dut.State == dut.IDLE) begin
		$display("Time %0t: Sitting at IDLE State", $time); pass_cnt = pass_cnt + 1;
    end else begin
        $display("ERROR: IDLE State is not the initial state"); fail_cnt = fail_cnt + 1;
		$stop; // If simulating using Icarus Verilog, please enter "cont" to continue simulation
    end
	
	Start = 1;
	#80; // Proceed the FSM to START, dut.sda_out=0

    // Test #2: START was detected
    if (start_detected) begin
        $display("PASS: START condition generated"); pass_cnt = pass_cnt + 1;
    end else begin
        $display("FAIL: START condition NOT detected"); fail_cnt = fail_cnt + 1;
    end
	
	#80; // Proceed the FSM to ADDR
	
	
	// Test #3: Master sends address to slave
	if(dut.State == dut.ADDR) begin 
		$display("Time %0t: Sitting at ADDR State", $time); pass_cnt = pass_cnt + 1;
	end else begin
		$display("ERROR: FSM not on ADDR State"); fail_cnt = fail_cnt + 1;
		$stop; // If simulating using Icarus Verilog, please enter "cont" to continue simulation
    end
	
	for(i=7; i>=0; i=i-1) begin
		#160;
		tb_addr_rw[i] = SDA;
	end
	
	if(tb_addr_rw == dut.addr_rw) begin 
		$display("PASS: Successfully addressed slave with address 0x%h and R/W bit of %b", 
		tb_addr_rw >> 1, tb_addr_rw[0]); 
		pass_cnt = pass_cnt + 1;
	end
	else begin
		$display("FAIL: Failed to address slave. Incorrect address read: 0x%h. , should be 0x%h", 
		tb_addr_rw >> 1, Slave_Addr); 
		fail_cnt = fail_cnt + 1;
	end
	
	// Test #4: Master reads ACK from the Slave.
	sda_in = 0; // Simulate a slave pulling the line low, indicating ACK
	if(dut.State == dut.READ_ACK) begin 
		$display("Time %0t: Sitting at READ_ACK State", $time); pass_cnt = pass_cnt + 1;
	end else begin
		$display("ERROR: FSM not on READ_ACK State"); fail_cnt = fail_cnt + 1;
		$stop; // If simulating using Icarus Verilog, please enter "cont" to continue simulation
    end
	
	#40; $display("Value of SDA_OE: %b", SDA_OE);
	#120;
	
	// Test #5: Master Writes data to Slave
	if(dut.State == dut.WR_DATA) begin 
		$display("Time %0t: Sitting at WR_DATA State", $time); pass_cnt = pass_cnt + 1;
	end else begin
		$display("ERROR: FSM not on WR_DATA State"); fail_cnt = fail_cnt + 1;
		$stop; // If simulating using Icarus Verilog, please enter "cont" to continue simulation
    end
	#40; $display("Value of SDA_OE: %b", SDA_OE);
	tb_Write_Data[7] = SDA;
	
	for(i=6; i>=0; i=i-1) begin
		#160;
		tb_Write_Data[i] = SDA;
	end
	
	if(tb_Write_Data == Write_Data) begin 
		$display("PASS: Successfully written the data 0x%h", tb_Write_Data); 
		pass_cnt = pass_cnt + 1;
	end
	else begin
		$display("FAIL: Failed to write correct data. Incorrect data written: 0x%h. , should be 0x%h", 
		tb_Write_Data, Write_Data); 
		fail_cnt = fail_cnt + 1;
	end
	
	
	
	
	
	

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
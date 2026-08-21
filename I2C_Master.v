module i2c_master #(parameter ADDR_WIDTH = 7, 
					parameter CLK_DIV = 125, // System clk: 50 MHz, need 100 kHz i2c clk with quarter bit resolution,
											 // so 50,000,000/(4*100,000) = 125
					parameter BYTES_TO_READ = 3)
(
	input CLK, RST,
	input [ADDR_WIDTH-1:0] Slave_Addr,
	input R_W,
	input [7:0] Write_Data,
	input Start, // When start is high on IDLE state, transition to START and then pull SDA low, wait, pull SCL low
	
	inout SDA, // SDA is inout because the master may be either tx or rx and sometimes must let go of the bus
	output reg SCL, // Since the master generates the clock only from his internal clk, SCL is output
	output reg SDA_OE,
	output reg Busy,
	output reg [7:0] Read_Data
);

	localparam IDLE  	  = 3'b000; // Both SCL & SDA lines are high
	localparam START 	  = 3'b001; // SDA goes low followed by SCL going low
	localparam ADDR   	  = 3'b010; // After Starting, receives the address bits and the R/W bit
	localparam READ_ACK   = 3'b011; // ACK/NACK received from the slave
	localparam SEND_ACK	  = 3'b100; // ACK/NACK sent from master
	localparam READ_DATA  = 3'b101; // Reading the data byte
	localparam WR_DATA    = 3'b110; // Writing the data byte
	localparam STOP       = 3'b111; // Both SCL & SDA lines go back to being high simultaneously
	
	reg  sda_out;
	reg  rw_bit;
	reg  [1:0] q_cnt;
	reg  [2:0] bytes_remaining;
	reg  [2:0] State;
	reg  [2:0] bit_idx;
	reg  [2:0] data_i;
	wire [7:0] addr_rw;
	
	assign SDA = SDA_OE ? sda_out : 1'bz
	assign addr_rw = {Slave_Addr, R_W};
	
	// Clock Divider Unit
	reg [6:0] div_cnt;
	reg       qbit;   // quarter-bit tick

	always @(posedge CLK) begin
		if (rst) begin 
			div_cnt <= 0; 
			qbit <= 0; 
		end // if
		
		else begin
			qbit <= 0;
			if (div_cnt == CLK_DIV - 1) begin
				div_cnt <= 0;
				qbit    <= 1;
			end // if
			else div_cnt <= div_cnt + 1;
		end // else
	end // always
	
	
	// Purpose: Determines whether the I2C Bus is busy or not.
	always@(*) begin
		if(RST == 1'b1 || State == IDLE) begin
			Busy <= 1'b0;
		end // if
		
		else begin
			Busy <= 1'b1;
		end // else
		
	end // always
	
	
	// Purpose: Finite State Machine for I2C Master
	always@(posedge qbit, posedge RST) begin
		if (RST) begin
			State <= IDLE;
			SCL <= 1'b1;	sda_out <= 1'b1;
			bytes_remaining <= BYTES_TO_READ;
			bit_idx <= 0;	q_cnt <= 0;
		end
			
		else begin
			case(State)
			
				IDLE: begin
					SDA_OE <= 1'b1;
					sda_out <= 1'b1;
					SCL <= 1'b1;
					if(Start) begin
						State <= START;
						q_cnt <= 0;
					end
				end // IDLE
				
				START: begin
					sda_out <= 1'b0;
					bit_idx <= 7;
					data_i <= 7;
					bytes_remaining <= BYTES_TO_READ;
					State <= ADDR;
				end // Start
				
				ADDR: begin
					sda_out <= addr_rw[bit_idx];
					if(bit_idx == 1'b0) begin
						rw_bit <= addr_rw[bit_idx];
						State <= READ_ACK;
					end
						bit_idx <= bit_idx - 1;
				end // ADDR
				
				READ_ACK: begin // Master is a transmitter (byte trasmitted by master, ack received by master)
					SDA_OE <= 1'b0;
					if(SDA == 1'b0) begin
						if(rw_bit == 1'b1)
							State <= READ_DATA;
						else if (rw_bit == 1'b0)
							State <= WR_DATA;
					end
					else
						State <= STOP;
				end // READ_ACK
				
				SEND_ACK: begin // Master is a receiver (byte received by master, ack transmitted by master)
					SDA_OE <= 1'b1;
					if(bytes_remaining == 1'b0) begin
						sda_out <= 1'b1;
						State <= STOP;
					end
					else begin
						sda_out <= 1'b0;
						State <= READ_DATA;
					end
				end // SEND_ACK
				
				READ_DATA: begin
					SDA_OE <= 1'b0;
					Read_Data[data_i] <= SDA;
					if(data_i == 0)
						State <= SEND_ACK;
					data_i <= data_i - 1;
				end
				
				WR_DATA: begin
					SDA_OE <= 1'b1;
					sda_out <= Write_Data[data_i];
					if(data_i == 0) begin
						State <= READ_ACK;
						bytes_remaining <= bytes_remaining - 1;
					end
					data_i <= data_i - 1;
				end
				
				STOP: begin
					sda_out <= 1;
					SCL <= 1;					
				end
			endcase
					
endmodule

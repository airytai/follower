module cmd_cntrl(clk, rst_n, cmd, cmd_rdy, clr_cmd_rdy, in_transit, OK2Move, go, buzz, buzz_n, ID, ID_vld, clr_ID_vld);

input clk, rst_n;			// Clock and active-low reset signal

input [7:0]	cmd;			// The command supplied to this module
input		cmd_rdy;		// A signal to indicate a new command is ready
output reg	clr_cmd_rdy;	// Asserted to acknowledge the command has been read

input [7:0]	ID;				// The ID read by the barcode reader
input		ID_vld;			// A signal tto indicate the ID value is valid
output reg	clr_ID_vld;		// Asserted to acknowledge the ID has been read

input		OK2Move;		// Deasserted if the proximity sensor detects an obstacle
output reg	in_transit;		// Asserted when the vehicle should be in transit
output reg	go;				// Asserted when the vehicle should be moving (in_transit && OK2Move)

output reg	buzz;           // Positive output for the 4kHz buzzer
output reg	buzz_n;         // Negative output for the 4kHz buzzer
reg [15:0]  buzz_cnt;		// Counter for buzz signal
reg         buzz_enable;	// Enable for the buzzer

localparam  BUZZ_INIT = 16'h00;     // Clears the buzzer counter
localparam  BUZZ_MAX  = 16'h30D4;   // Counter value used for a 4kHz signal

reg [7:0]	dest_ID;		// The barcode ID that the vehicle wants to stop at

reg [2:0]	movingCase;

// Possible states, current state, and next state
typedef enum reg {NOT_MOVING, MOVING} state_t;
state_t state;
state_t next_state;

// Commands this module cares about
localparam GO_CMD = 2'b01;
localparam STOP_CMD = 2'b00;

// Set state to be the next state
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		state <= NOT_MOVING;
	else
		state <= next_state;
end

// Next state logic
always_comb begin
	clr_ID_vld  = 0;
	movingCase  = 0;

	case (state)
		NOT_MOVING : begin
			if (cmd_rdy && (cmd[7:6] == GO_CMD))
				next_state = MOVING;
			else
				next_state = NOT_MOVING;
		end

		MOVING : begin
			if (cmd_rdy && (cmd[7:6] == GO_CMD)) begin
				next_state = MOVING;
				movingCase = 3'h1;
			end
			else if (cmd_rdy && (cmd[7:6] == STOP_CMD)) begin
				next_state = NOT_MOVING;
				movingCase = 3'h2;
			end
			else if (!ID_vld) begin
				next_state = MOVING;
				movingCase = 3'h3;
			end
			else if (ID == dest_ID) begin
				clr_ID_vld = 1;
				next_state = NOT_MOVING;
				movingCase = 3'h4;
			end
			else begin
				clr_ID_vld = 1;
				next_state = MOVING;
				movingCase = 3'h5;
			end
		end
	endcase

	if (!rst_n)
		next_state = NOT_MOVING;
end

// Set the destination ID when cmd_rdy is asserted and the command is GO
always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		dest_ID = 0;
	else if (cmd_rdy && (cmd[7:6] == GO_CMD))
		dest_ID = {2'b0, cmd[5:0]};
end

// in_transit is asserted when in the moving state only
assign in_transit = (state == MOVING) ? 1'b1 : 1'b0;

// The vehicle should be moving when there is no obstacle and it is in transit
assign go = OK2Move & in_transit;

// Buzzer logic
always @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
		buzz <= 1'b0;
		buzz_cnt <= BUZZ_INIT;
	end
	else begin
		
		if (buzz_enable)
			buzz_cnt <= buzz_cnt + 1'b1;

		if (buzz_cnt >= BUZZ_MAX / 2)		// 50% duty cycle
			buzz <= 1'b1;
		else
			buzz <= 1'b0;
		if (buzz_cnt == BUZZ_MAX)			// Prevent overflow
			buzz_cnt <= BUZZ_INIT;

		
	end
end
assign buzz_n = (buzz_enable) ? ~buzz : buzz;

// Buzzer enable logic
assign buzz_enable = in_transit && (!OK2Move);

always @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		clr_cmd_rdy = 1'b0;
	else if(cmd_rdy)
		clr_cmd_rdy = 1'b1;	
	else 
		clr_cmd_rdy = 1'b0;
end


endmodule

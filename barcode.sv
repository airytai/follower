module barcode(BC, ID_vld, ID, clr_ID_vld, rst_n, clk);

input clk, rst_n;
input BC; // input station ID series
output reg ID_vld;
output reg [7:0] ID;
input clr_ID_vld;

reg [21:0] cpt_cnt; // the counter to count the value to capture
reg strt_cpt; // the signal to start the capture counter when see the falling edge of start bit
// reg end_cpt; // assert to end capture to save energy and reset the capture counter

reg [21:0] cnt; // counter to count to the capture value and shift the shifter
reg shift; // asserted to shift the shifter
reg [7:0] ID_reg; // register for ID
reg strt_cnt; // start the counter
reg clr_cnt; // clr the counter
reg set_cnt; // assert to start the counter

reg [21:0] cpt_value; // the value captured
reg clr_cpt_value = 1'b0; // asserted to clr the cpt value
reg set_cpt_value = 1'b0; // asserted to set the cpt value

reg ff_1, ff_2, ff_logic; // double ff to detect the falling edge of BC
reg falling_edge; // asserted when falling edge is detected

reg cnt_match_cpt; // counter match the value of period cpt

reg [3:0] index_cnt; // 4 bit to count 8
reg compare; // assert to enable cnt_match_cpt to start compare, otherwise, when rst_n asserted, both cnt and cpt_value are zero, shifter will be triggered

typedef enum reg[1:0] {IDLE, CAP, SAMP} state_t;
state_t state, state_nxt;

// set the cpt_value
always@(posedge clk, negedge rst_n) begin
    if(!rst_n)
        cpt_value <= 22'h000000;
    else if(clr_cpt_value)
        cpt_value <= 22'h000000;
    else if(set_cpt_value)// if strt_cpt asserted
        cpt_value <= cpt_cnt;
end
//////////risk of cpt_value <= cpt_cnt, cpt_cnt is already 0

// set the strt_cnt signal
always@(posedge clk, negedge rst_n) begin
    if(!rst_n)
        strt_cnt <= 1'b0;
    else if(clr_cnt)
        strt_cnt <= 1'b0;
    else if(set_cnt)// if strt_cpt asserted
        strt_cnt <= 1'b1; // assert strt_cnt to start incrementing the cnt value
end

// start the capture
always@(posedge clk, negedge rst_n) begin
    if(!rst_n)
        cpt_cnt <= 22'h000000;
    else if(!strt_cpt)
        cpt_cnt <= 22'h000000;
    else // if strt_cpt asserted
        cpt_cnt <= cpt_cnt + 1'b1;
end

// validate the ID
// if upper 2 bit must be 00
// assign ID_vld = ~|ID[7:6]; // if both are 0, OR are 0, neg are 1, ID_vld is asserted

// clear ID_vld when clr_ID_vld is asserted
always@(posedge clk, negedge rst_n) begin
    if(!rst_n)
        ID_vld <= 1'b0;
    else if(clr_ID_vld)
        ID_vld <= 1'b0;
    else
        ID_vld <= ~|ID[7:6];
end

// BC falling edge detector
always@(posedge clk, negedge rst_n)
        begin
        if(!rst_n)
            ff_1 <= 1'b1;
        else
            ff_1 <= BC;
            ff_2 <= ff_1;
            ff_logic <= ff_2;
        end

assign falling_edge = !ff_2 & ff_logic;
assign rising_edge = ff_2 & !ff_logic;

// cnt to the capture value, assert shift
always@(posedge clk, negedge rst_n) begin
    if(!rst_n)
        cnt <= 22'h000000;
    else if(clr_cnt)
        cnt <= 22'h000000;
    else if(strt_cnt)
        cnt <= cnt + 1'b1;
end

// check match
always@(posedge clk, negedge rst_n) begin
    if(!rst_n)
        cnt_match_cpt <= 1'b0;
    else if((cnt == cpt_value) & compare) // if cnt == cpt_cnt
        cnt_match_cpt <= 1'b1; // assert cnt_match_cpt for one cycle
    else
        cnt_match_cpt <= 1'b0; // deassert
end

// assert shift if match
always@(posedge clk, negedge rst_n) begin
    if(!rst_n)
        shift <= 1'b0;
    else if(cnt_match_cpt) // if cnt == cpt_cnt
        shift <= 1'b1; // assert shift
    else
        shift <= 1'b0; // deassert
end

// shifter register, lft shift, MSB first
always@(posedge clk, negedge rst_n) begin
    if(!rst_n)
        ID_reg <= 8'h00;
    else if(shift) // left shift
        ID_reg <= {ID_reg, BC}; 
end

// initiate state transition
always@(posedge clk, negedge rst_n) begin
    if (!rst_n)
        state <= IDLE;
    else
        state <= state_nxt;
end

// index_cnt to count number of BC shift in and latch the output if finish
always@(posedge clk, negedge rst_n) begin
    if (!rst_n)
        index_cnt <= 4'h0;
    else if(shift)
        index_cnt <= index_cnt + 1'b1;
end

// SM, IDLE
// CAP: capture state to set the strt_cpt as 1 to start capture counter
// clr_cnt asserted when in CAP state
// if(cnt_match_cpt) assert clr_cnt to get the counter reset to 0
// deassert the holder and restart the strt_cnt when falling edge detected
always@(state, falling_edge, rising_edge, cnt_match_cpt, index_cnt) begin
    // end_cpt = 1'b1; // default to end the capture
    // strt_cnt = 1'b0;
    compare = 1'b0;
    clr_cnt = 1'b0;
    clr_cpt_value = 1'b0; // asserted to clr the cpt value
    set_cpt_value = 1'b0; // asserted to set the cpt value
    strt_cpt = 1'b0; // default to no capture
    state_nxt = IDLE;
    
    case(state)
        IDLE: begin // waiting if BC keep high and start bit (low) never arrive
	    set_cnt = 1'b0;
            if(falling_edge) // see the starting bit falling edge
                state_nxt = CAP; // go to capture state
        end
        CAP: begin
            // end_cpt = 1'b0; // deassert end_cpt to let the capture work
            strt_cpt = 1'b1; // assert to start the capture
            if(rising_edge) begin // rising edge means end of the low period of the bit duration
                // end_cpt = 1'b1;
                strt_cpt = 1'b0;
                set_cpt_value = 1'b1;
                state_nxt = SAMP;
            end
            else
                state_nxt = CAP;
        end
        default: begin // SAMP state
            compare = 1'b1;
            if(falling_edge) begin
                set_cnt = 1'b1;
                state_nxt = SAMP;
            end
            else if(cnt_match_cpt) begin
                clr_cnt = 1'b1;
		set_cnt = 1'b0;
                state_nxt = SAMP;
            end
            else if(index_cnt == 4'h8) begin
                ID = ID_reg;
                clr_cpt_value = 1'b1;
                state_nxt = IDLE;
            end
            else begin
                state_nxt = SAMP;
            end
        end
    endcase
end

endmodule
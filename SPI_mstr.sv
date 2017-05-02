// SPI_mstr.v
module SPI_mstr(clk, rst_n, wrt, cmd, done, rd_data, SCLK, SS_n, MOSI, MISO);
    
    input clk, rst_n, wrt;
    input [15:0] cmd;
    output reg done;
    output [15:0] rd_data;
    output reg SS_n;
    output SCLK, MOSI;
    input MISO;

    typedef enum reg[2:0] {IDLE, SKIP_1st_fall, TMIT, B_P, WAIT} state_t;
    state_t state, state_nxt;

    reg [4:0] index_cnt; // 5 bits so that we can reach 16
    reg shift, shift_cmd;
    reg set_dummy_finish;
    reg clr_dummy_finish;
    reg dummy_finish;
    // create a counter to count the shift index (5 bits)
    // increment when shift is asserted
    // reset when SS_n is high
    always@(posedge clk, negedge rst_n)
        begin
            if(!rst_n)
                index_cnt <= 5'h00; // 0_0000
            else if(SS_n || set_dummy_finish)
                index_cnt <= 5'h00; // reset when transmission end
            else if(shift)
                index_cnt <= index_cnt + 1'b1;
        end
    // ?? any risk of directly using SS_n


    reg clr_SCNT;
    reg [4:0] SCLK_cnt;
    reg B_P_end;
    // reg wait_1st_fall; // asserted if 1st fall hasnt met, default 1
    // create a counter for SCLK
    // incremented per clk cycle, when SS_n is low
    // reset as 5'h10;(decimal 16)
    // shift is asserted for 1 clk when bit[4] is 0 (falling edge)
    // skip the first falling edge shift
    // assign SCLK
    always@(posedge clk, negedge rst_n)
        begin
            if(!rst_n || clr_SCNT)
                SCLK_cnt <= 5'h10; // 1_0000, decimal 16
            else if( (state != WAIT) && SS_n)
                SCLK_cnt <= 5'h10; // not enabled if SS_n high
            else
                SCLK_cnt <= SCLK_cnt + 1'b1; // increment whenever meet next posedge of clk
        end
    
    assign SCLK = SCLK_cnt[4]; // default as 1
    assign B_P_end = &SCLK_cnt[4:3];
    // only if SCLK_cnt = 0_0000 (SCLK fall), shift is 1
    // if still wait for 1st fall, shift never be asserted
    // assign shift = (wait_1st_fall) ? 1'b0 : SCLK_fall;
    // ?? any risk of directly using SS_n


    // detect SCLK fall edge and rise edge
    wire SCLK_fall;
    wire SCLK_rise;
    reg SCLK_ff1,SCLK_ff2;	// used for falling edge detection of SCLK
    // detect fall and rise
    // assign SCLK_fall = ~|SCLK_cnt; // when SCLK_cnt = 0
    // assign SCLK_rise = (!SS_n) ? SCLK_cnt[4]&(~(|SCLK_cnt[3:0])) : 1'b0; // when SCLK_cnt = 1_0000
    // need to deal with the problem of first rise and last rise
    // ?? use ff
    always@(posedge clk, negedge rst_n)
        if (!rst_n)
        begin
            SCLK_ff1 <= 1'b1;
            SCLK_ff2 <= 1'b1;
        end
        else
        begin
            SCLK_ff1 <= SCLK_cnt[4];
            SCLK_ff2 <= SCLK_ff1;
        end  
    assign SCLK_fall = ~SCLK_ff1 & SCLK_ff2;
    assign SCLK_rise = SCLK_ff1 & ~SCLK_ff2;

    reg [15:0] rd_data_reg;
    // create shift register for rd_data 
    // do shift if shift asserted
    // left shift, MISO into LSB
    // rd_data = this.shifter
    always@(posedge clk, negedge rst_n)
        begin
            if(!rst_n)
                rd_data_reg <= 16'h0000; // default as 0
            else if(shift)
                rd_data_reg <= {rd_data_reg[14:0], MISO};
        end
    assign rd_data = rd_data_reg;
    // ?? risk of whether we really need to skip the first fall

    logic set_done, clr_done;
    // set_done and clr_done to operate on done
    always@(posedge clk, negedge rst_n)
        begin
            if(!rst_n)
                done <= 1'b0;
            else if(clr_done)
                done <= 1'b0;
            else if(set_done)
                done <= 1'b1;
        end
    // ?? risk of default done as 0, but this 0 can control the trmt_strt

    reg trmt_strt; // transmission start
    reg clr_trmt_strt;
    reg set_trmt_strt;
    reg [15:0] cmd_reg;
    // SS_n deasserted when wrt asserted
    // also load cmd
    always@(posedge clk, negedge rst_n)
        begin
            if(!rst_n) begin
                trmt_strt <= 1'b0;
            end else if(wrt || set_trmt_strt) begin
                trmt_strt <= 1'b1;
            end else if(clr_trmt_strt)
                trmt_strt <= 1'b0; // if done, reset
        end
    assign SS_n = ~trmt_strt; // default high
    // ?? risk of direct use of done
    // pay attention to the time done is asserted to clear SS_m
    // note that done should only be asserted for 1 clk
    // state machine set set_done, when &SCLK_cnt[4:3] = 1, take only the first two bits
    // next clk, state go to IDLE, as well as assert done,
    // next clk, SS_n clear
    
    always@(posedge clk, negedge rst_n)
        begin
            if(!rst_n || clr_dummy_finish) begin
                dummy_finish <= 1'b0;
            end else if(set_dummy_finish) begin
                dummy_finish <= 1'b1;
            end
        end
    // MOSI
    // shift cmd for MOSI 
    // shift when shift_cmd is asserted
    // left shift
    // shift out bit is MOSI
    always@(posedge clk, negedge rst_n)
        begin
            if(!rst_n)
                cmd_reg <= 16'h0000;
            else if(wrt) begin
                cmd_reg <= cmd; // load
				end else if (shift_cmd)
					 cmd_reg <= {cmd_reg[14:0], 1'b0};	
        end
    assign MOSI = (SS_n) ? 1'bx : cmd_reg[15];


    always@(posedge clk, negedge rst_n)
        if (!rst_n)
            state <= IDLE;
        else
            state <= state_nxt;
    // State Machine
    // IDLE: when for wrt asserted
    // SKIP_1st_fall : skip the first falling edge, hold the shift
    // TMIT: when index_cnt = 16, go next
    // B_P (back_porch): SCLK should be low when enter this state,
    // wait for SCLK counter [4:3] AND = 1, go IDLE

    always@(wrt, SCLK_fall, SCLK_rise, state, index_cnt, B_P_end)
        begin
            // default
            shift = 1'b0;
            shift_cmd = 1'b0;
            clr_done = 1'b0;
            set_done = 1'b0;
            clr_SCNT = 1'b0;
            clr_trmt_strt = 1'b0;
            state_nxt = IDLE;
            clr_dummy_finish = 1'b0;
            set_dummy_finish = 1'b0;
            set_trmt_strt = 1'b0;

            case(state)
                IDLE: begin
                    if(wrt) begin // when wrt asserted, next cycle SS_n keep active low until done is set
                        clr_done = 1'b1;
                        state_nxt = SKIP_1st_fall;
                    end
                end
                // skip the first fall edge
                SKIP_1st_fall: begin
                    set_trmt_strt = 1'b1;
                    shift = SCLK_rise; // 0
                    if (SCLK_fall)
                        state_nxt = TMIT;
                    else
                        state_nxt = SKIP_1st_fall;
                end
                TMIT: begin
                    shift = SCLK_rise;
                    shift_cmd = SCLK_fall;
                    if(index_cnt == 16)
                        state_nxt = B_P;
                    else
                        state_nxt = TMIT;
                end
                B_P: begin
                    state_nxt = B_P;
                    if (B_P_end) begin
                        clr_SCNT = 1;
                        state_nxt = WAIT;
                        clr_trmt_strt = 1'b1;
                    end
                end
                WAIT: begin
                    state_nxt = WAIT;
                    if (SCLK == 1'b1) begin
                        if(dummy_finish) begin
                            state_nxt = IDLE;
                            set_done = 1'b1;
                            clr_dummy_finish = 1'b1;
                        end
                        else begin
                            set_dummy_finish = 1'b1;
                            state_nxt = SKIP_1st_fall; // start the second transaction
                        end
                    end
                end
            endcase
        end

endmodule

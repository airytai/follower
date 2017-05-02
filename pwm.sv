// PWM generator
module pwm(duty, clk, rst_n, PWM_sig);
    //////////////////////////////////////////////////////
    ///////// should we have input clk, rst_n??? /////////
    //////////////////////////////////////////////////////

    input [7:0] duty; // input 10-bit-width unsigned signal.
    input clk; // clk signal
    input rst_n; // reset signal
    output reg PWM_sig; // 1-bit-width output PWN signal.

    reg [7:0] cnt; // 10-bit counter
    reg [7:0] nxt_cnt; // next counting signal 

    reg cnt_set; // set signal for producing PWM_sig
    reg cnt_rst; // reset signal for producing PWM_sig

    reg cnt_d; // the input D signal for the asychronous FF
    // implement 10-bit counter with synchronous reset
    ////////////////////////////////////
    ///////// how give count?  /////////
    ////////////////////////////////////
    always @(posedge clk)
        if(!rst_n)
            cnt <= 8'b0000_0000;
        else
            cnt <= nxt_cnt;

    always @(*)
	nxt_cnt = cnt + 1;
    
    // check whether the count cycle meet the duty cycle
    always @(duty or cnt)
        begin
            // default set and rst signal to avoid latches
            cnt_set = 1'b0;
            cnt_rst = 1'b0;

            if(cnt == duty)
                cnt_rst = 1'b1;
            else if(cnt == 8'b1111_1111)
                cnt_set = 1'b1;
        end
    // implement the combinational logic for set, reset, or recirulate
    ///////////////////////////////////////////////////
    ///////// latch may occur for PWM_sig???  /////////
    ///////////////////////////////////////////////////
    always @(cnt_set or cnt_rst or PWM_sig)
        if(cnt_set)
            cnt_d = 1'b1;
        else if(cnt_rst)
            cnt_d = 1'b0;
        else
            cnt_d = PWM_sig;

    // implement the asynchronous FF
    always @(posedge clk or negedge rst_n)
        if(!rst_n)
            PWM_sig <= 1'b0;
        else
            PWM_sig <= cnt_d;

endmodule
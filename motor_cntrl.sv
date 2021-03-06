module motor_cntrl(lft, rht, fwd_lft, rev_lft, fwd_rht, rev_rht, rst_n, clk);

    input rst_n, clk;
    input [10:0] lft, rht; // signed speed of left/right motor
    output reg fwd_lft, rev_lft, fwd_rht, rev_rht; // Forward/reverse PWM signal of left right motor

    wire sign_lft, sign_rht; // the sign of the input speed
    wire PWM_sig_lft, PWM_sig_rht; // PWM sign of left and right
    wire brake_lft, brake_rht; // brake of left and right

	wire [9:0] duty_lft;
	wire [9:0] duty_rht;

    // check the sign
    assign sign_lft = lft[10];
    assign sign_rht = rht[10];
    assign brake_lft = ~|lft; // OR lft = 0, assert brake to true
    assign brake_rht = ~|rht;

	// Absolute value of the duty cycle
	// assign duty_lft = (sign_lft) ? (~lft[9:0]) : (lft[9:0]);
	// assign duty_rht = (sign_rht) ? (~rht[9:0]) : (rht[9:0]);
    assign duty_lft = (lft[10]) ? ((lft[9:0]==10'h000) ? 10'h3ff : (11'h400 - lft[9:0])) : lft[9:0];
    assign duty_rht = (rht[10]) ? ((rht[9:0]==10'h000) ? 10'h3ff : (11'h400 - rht[9:0])) : rht[9:0];

    // pipe
    pwm_10 iDUT_lft(.duty(duty_lft[9:0]), .clk(clk), .rst_n(rst_n), .PWM_sig(PWM_sig_lft));
    pwm_10 iDUT_rht(.duty(duty_rht[9:0]), .clk(clk), .rst_n(rst_n), .PWM_sig(PWM_sig_rht));

    // drive lft
    always@(posedge clk, negedge rst_n) begin
        if(!rst_n) begin // reset as brake condition
            fwd_lft = 1'b1;
            rev_lft = 1'b1;
        end
        else if(brake_lft) begin // if brake override PWM
            fwd_lft = 1'b1;
            rev_lft = 1'b1;
        end
        else if(sign_lft) begin // lft goes reverse
            rev_lft = PWM_sig_lft;
            fwd_lft = 1'b0;
        end
        else begin // lft goes fwd
            fwd_lft = PWM_sig_lft;
            rev_lft = 1'b0;
        end
    end

    // drive right
    always@(posedge clk, negedge rst_n) begin
        if(!rst_n) begin // reset as brake condition
            fwd_rht = 1'b1;
            rev_rht = 1'b1;
        end
        else if(brake_rht) begin // if brake override PWM
            fwd_rht = 1'b1;
            rev_rht = 1'b1;
        end
        else if(sign_rht) begin // rth goes reverse
            rev_rht = PWM_sig_rht;
            fwd_rht = 1'b0;
        end
        else begin // rht goes fwd
            fwd_rht = PWM_sig_rht;
            rev_rht = 1'b0;
        end
    end

endmodule

// shold I turn all the block assignment to unblock?
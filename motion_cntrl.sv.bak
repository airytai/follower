module motion_cntrl(strt_cnv, chnnl, IR_in_en, IR_mid_en,IR_out_en,LEDs,lft,rht,go,cnv_cmplt,A2D_res,clk,rst_n);
input go;
input cnv_cmplt;
input[11:0]  A2D_res ;
input clk;
input rst_n;
output  reg strt_cnv;
output reg [2:0] chnnl;
output  reg IR_in_en;
output reg IR_mid_en;
output  reg IR_out_en;
output reg [7:0] LEDs;
output  reg [10:0] lft;
output reg [10:0] rht;
reg [2:0] chnnlcounter;
reg intimer1;
reg intimer2;
reg timer1; 
reg timer2;
reg [4:0] counter2;
reg [11:0] counter1;

reg rst_counter1_n;
reg rst_counter2_n;

reg signed [15:0] Accum;
// reg [11:0] Error;
// reg [15:0] Pcomp;
// reg [11:0] Intgrl;
// reg [11:0] Icomp;
reg [11:0] lft_reg;
reg [11:0] rht_reg;
reg [11:0] Fwd;
reg [2:0] int_dec;
reg signed [15:0] dst; // change to 16 bit width
wire pwm_output; 
localparam DUTY_CYCLE = 8'h8C;


reg signed [15:0] Pcomp; // Accum: Accum for error build-up; Pcomp: P component of PI control
reg [13:0] Pterm; // P term in the PI control
reg [11:0] Icomp, Error, Intgrl;
reg [11:0] Iterm;
reg [2:0] src0sel, src1sel; // input signal with 3 bit width, used for source selection in MUX 0 and 1
reg multiply, sub, mult2, mult4, saturate; 
   
// reg signed [15:0] alu_dst; // result of ALU

reg dst2Accum,dst2Err,dst2Int,dst2Icmp,dst2Pcmp,dst2lft,dst2rht; // signal used to determine where dst go
reg waitcounter;
reg clr_waitcounter;
reg set_waitcounter;
reg clr_int_dec;
reg set_int_dec;

// A2D_intf iDUT_A2D_intf( .clk(clk), .rst_n(rst_n), .strt_cnv(strt_cnv), .cnv_cmplt(cnv_cmplt), .chnnl(chnnl), .res(res), .a2d_SS_n(a2d_SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));
// ADC128S iDUT_ADC128S( .clk(clk), .rst_n(rst_n), .SS_n(a2d_SS_n), .SCLK(SCLK), .MISO(MISO), .MOSI(MOSI));
alu iDUT_alu(.Accum(Accum), .Pcomp(Pcomp), .Icomp(Icomp), .Pterm(Pterm), .Iterm(Iterm), .Fwd(Fwd), .A2D_res(A2D_res), .Error(Error), .Intgrl(Intgrl), .src0sel(src0sel), .src1sel(src1sel), .multiply(multiply), .sub(sub), .mult2(mult2), .mult4(mult4), .saturate(saturate), .dst(dst));
pwm iDUT_pwm(.duty(DUTY_CYCLE),.clk(clk),.rst_n(rst_n),.PWM_sig(pwm_output));

assign dst2Int=(int_dec==3'b100)?1'b1:1'b0;

typedef enum reg [4:0] {RESET,TIMER1,CONVCOMPLETE1,TIMER2,CONVCOMPLETE2, CHECK6, INTG,ITERM, PTERM, MRT_R1, MRT_R2, MRT_L1, MRT_L2} state_t;
state_t state, next_state;

always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		Fwd <= 12'h000;
	else if (~go) // if go deasserted Fwd knocked down so
		Fwd <= 12'b000; // we accelerate from zero on next start.
	else if (dst2Int & ~&Fwd[10:8]) // 43.75% full speed
		Fwd <= Fwd + 1'b1;
end

always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		rht_reg <= 12'h000;
	else if (!go)
		rht_reg <= 12'h000;
	else if (dst2rht)
		rht_reg <= dst[11:0];
end

always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		lft_reg <= 12'h000;
	else if (!go)
		lft_reg <= 12'h000;
	else if (dst2lft)
		lft_reg <= dst[11:0];
end

always @(posedge clk, negedge rst_n) begin
	if(!rst_n || !rst_counter1_n)
		counter1<=12'h000;
	else if(intimer1)
		counter1=counter1+1;
end

always @(posedge clk, negedge rst_n) begin
	if(!rst_n || !rst_counter2_n)
		counter2<=5'd0;
	else if(intimer2)
		counter2=counter2+1;
end

assign timer2 = &counter2;

assign timer1 = &counter1;

always_ff @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		state <= RESET;
	else
		state <= next_state;
end

always_comb begin
	if(!rst_n)begin
		chnnlcounter = 0;
		chnnl = 0;
		rst_counter1_n = 1'b1;
		rst_counter2_n = 1'b1;
	end

	//default outputs// 
	clr_waitcounter = 0;
	set_waitcounter = 0;
	set_int_dec = 1'b0;
	strt_cnv=0;
	intimer1=0;
	intimer2=0;
	next_state=RESET;

	multiply = 0;
	sub = 0;
	mult2 = 0;
	mult4 = 0;
	saturate = 0;
	src0sel = 0;
	src1sel = 0;

	dst2Accum = 0;
	dst2Err=0;
	dst2Icmp=0;
	dst2Pcmp=0;
	dst2lft=0;
	dst2rht=0;
	
	// int_dec=0; // where could we set this
	
	case(state)
		RESET: begin
			chnnlcounter = 0;
			chnnl = 0;
			if(go) begin
		        next_state=TIMER1;				
				// add code that Enables PWM and Enables timer
			end
		end
		TIMER1: begin
			if(timer1)begin
				strt_cnv = 1;
				rst_counter1_n = 1'b0;
				next_state = CONVCOMPLETE1;
				// Enables PWM
				if(chnnlcounter==0) begin
					chnnl=1;
					// IR_in_en = pwm_output;
				end
				if(chnnlcounter==2) begin
					chnnl=4;
					// IR_mid_en = pwm_output;
				end
				if(chnnlcounter==4)begin
					chnnl=3;
					// IR_out_en = pwm_output;
				end
			end
			else begin
				intimer1=1; // start to count timer1
				next_state=TIMER1;
			end
		end
		CONVCOMPLETE1: begin
			if(cnv_cmplt) begin
				rst_counter1_n = 1'b1;
				next_state = TIMER2;

				// add code to perform one of the 3 calculations based on chnnl counter 
				if(chnnl == 1) begin
					dst2Accum = 1;
				end
				if(chnnl == 4) begin
					mult2 = 1;
					dst2Accum = 1;
				end
				if(chnnl == 3) begin
					mult4 = 1;
					dst2Accum = 1;
				end
				// clear timer
				chnnlcounter=chnnlcounter+1;
				
			end
			else
				next_state=CONVCOMPLETE1;
		end
		TIMER2: begin
			if(timer2)begin
				strt_cnv = 1;
				rst_counter2_n = 1'b0;
				next_state = CONVCOMPLETE2;

				if(chnnlcounter==1)begin
					chnnl=0;
					// IR_in_en = pwm_output;
				end
	
				if(chnnlcounter==3) begin
					chnnl=2;
					// IR_mid_en = pwm_output;
				end
				if(chnnlcounter==5)begin
					chnnl=7;
					// IR_out_en = pwm_output;
					end
			end
			else begin
				intimer2=1;
				next_state=TIMER2;
			end
		end
		CONVCOMPLETE2: begin
			if(cnv_cmplt) begin
				chnnlcounter=chnnlcounter+1;
				rst_counter2_n = 1'b1;
				next_state=CHECK6;
				// add code to perform one of the 3 calculations based on chnnl counter
				if(chnnl == 0) begin
					sub = 1;
					dst2Accum = 1;
				end
				if(chnnl == 2) begin
					sub = 1;
					mult2 = 1;
					dst2Accum = 1;
				end
				if(chnnl == 7) begin // Error= Accum - IR_out_lft*4
					saturate = 1;
					sub = 1;
					mult4 = 1;
					dst2Err = 1;
				end
				// clear timer
			end
				else
				next_state=CONVCOMPLETE2;
		end
		CHECK6:
			if(chnnlcounter==6) begin
				chnnl = 6;
				next_state=INTG; // go to integration state
			end else begin
				next_state=TIMER1; // otherwise count again
				end
		INTG: begin
			saturate = 1;
			src1sel = 3;
			src0sel = 1;
			set_int_dec = 1'b1;
			next_state = ITERM;
			clr_waitcounter = 1; // for multiplicate
			// do we need to store Intgrl anywhere?
		end
		ITERM: begin
			// Icomp = Iterm*Intgrl
			src1sel = 1;
			src0sel = 1;
			dst2Icmp = 1;
			multiply = 1;
			if(waitcounter)  begin 
				next_state = PTERM;
				clr_waitcounter = 1; // reset waitcounter for next state
			end else begin
				next_state = ITERM;
				set_waitcounter = 1;
			end
		end
		PTERM: begin
			// Pcomp = Error*Pterm
			src1sel = 2;
			src0sel = 4;
			dst2Pcmp = 1;
			multiply = 1;
			if(waitcounter)
				next_state = MRT_R1;
			else begin
				next_state = PTERM;
				set_waitcounter = 1;
			end
		end
		MRT_R1: begin
			// Accum = Fwd - Pcomp
			src1sel = 4;
			src0sel = 3;
			dst2Accum = 1;
			next_state = MRT_R2;
		end
		MRT_R2: begin
			// rht_reg = Accum – Icomp
			saturate  = 1;
			src1sel = 0;
			src0sel = 2;
			dst2rht = 1;
			next_state = MRT_L1;
		end
		MRT_L1: begin
			// Accum = Fwd + Pcomp
			src1sel = 4;
			src0sel = 3;
			dst2Accum = 1;
			next_state = MRT_L2;
		end
		MRT_L2: begin
			// lft_reg = Accum + Icomp
			saturate  = 1;
			src1sel = 0;
			src0sel = 3;
			dst2lft = 1;
			next_state = RESET;
		end
	endcase 
end

always @(posedge clk, negedge rst_n) begin
	if(!rst_n || !go) begin 
		Accum = 0;
		Error = 0;
		Intgrl = 0;
		Icomp = 0;
		Pcomp = 0;
		Pterm = 14'h3680;
		Iterm = 12'h500;
	end
	else if(dst2Accum)
		Accum = dst;
	else if(dst2Err)
		Error = dst;
	else if(dst2Int)
		Intgrl = dst;
	else if(dst2Icmp)
		Icomp = dst;
	else if(dst2Pcmp)
		Pcomp = dst;
end

always @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		IR_in_en = 0;
		IR_mid_en = 0;
		IR_out_en = 0;
	end else if(chnnlcounter==0 || chnnlcounter==1)
		IR_in_en = pwm_output;
	else if(chnnlcounter==2 || chnnlcounter==3)
		IR_mid_en = pwm_output;
	else if(chnnlcounter==4 || chnnlcounter==6)
		IR_out_en = pwm_output;
end

assign LEDs = Error[11:4];
assign lft = lft_reg[11:1];
assign rht = rht_reg[11:1];

always @(posedge clk, negedge rst_n) begin
	if(!rst_n) begin
		waitcounter <= 1'b0;
	end else if(clr_waitcounter)
		waitcounter <= 1'b0;
	else if(set_waitcounter)
		waitcounter <= 1'b1;
end

always @(posedge clk, negedge rst_n) begin
	if(!rst_n || clr_int_dec) begin
		int_dec <= 1'b0;
	end else if(set_int_dec)
		int_dec <= int_dec + 1'b1;
end

assign clr_int_dec = (dst2Int)?1'b1:1'b0;

endmodule


module alu (Accum, Pcomp, Icomp, Pterm, Iterm, Fwd, A2D_res, Error, Intgrl,
	src0sel, src1sel, multiply, sub, mult2, mult4, saturate, dst);

/********************
 * Local Parameters *
 ********************/

// src1 select localparams
localparam Accum2Src1	= 3'b000;
localparam Iterm2Src1	= 3'b001;
localparam Err2Src1		= 3'b010;
localparam ErrDiv22Src1	= 3'b011;
localparam Fwd2Src1		= 3'b100;

// src0 select localparams
localparam A2D2Src0		= 3'b000;
localparam Intgrl2Src0	= 3'b001;
localparam Icomp2Src0	= 3'b010;
localparam Pcomp2Src0	= 3'b011;
localparam Pterm2Src0	= 3'b100;

/**********************
 * Inputs and Outputs *
 **********************/

// src1 Inputs
input		 [2:0]  src1sel;
input signed [15:0] Accum;
input		 [11:0] Iterm;
input signed [11:0] Error;
input		 [11:0] Fwd;

// src0 Inputs
input		 [2:0]  src0sel;
input signed [15:0] Pcomp;
input signed [11:0] Icomp;
input		 [13:0] Pterm;
input		 [11:0] A2D_res;
input signed [11:0] Intgrl;

// Operation Signals
input multiply;
input sub;
input mult2;
input mult4;
input saturate;

// Output
output signed [15:0] dst;

// Source Multiplexing Wires
wire signed [15:0] pre_src0;
wire signed [15:0] shift_src0;
wire signed [15:0] src0;
wire signed [15:0] src1;

// Addition Logic Wires
wire signed [15:0] add_result;
wire signed        add_cout;
wire signed [15:0] add_sat_pos_val;
wire signed [15:0] add_sat_neg_val;
wire signed [15:0] add_sat_final_val;
wire signed [15:0] add_final;

// Multiplication Logic Wires
wire signed [15:0] mul_src1;
wire signed [15:0] mul_src0;
wire signed [29:0] mul_result;
wire signed [15:0] mul_sat_pos_val;
wire signed [15:0] mul_sat_neg_val;
wire signed [15:0] mul_final;

/********************************
 * Actual ALU Logic Starts Here *
 ********************************/

/*************************************
 * Multiplexer Input Selection Logic *
 *************************************/

// Set src1 based on src1sel
assign src1 =	(src1sel == Accum2Src1)		?	Accum :							// Accum (already 16 bits wide)
				(src1sel == Iterm2Src1)		?	{4'b0000,Iterm} :				// Zero-extended Iterm
				(src1sel == Err2Src1)		?	{{4{Error[11]}},Error} :		// Sign-extended Error
				(src1sel == ErrDiv22Src1)	?	{{8{Error[11]}},Error[11:4]} :	// Sign-extended, right shifted Error
				(src1sel == Fwd2Src1)		?	{4'b0000,Fwd} :					// Zero-extended Fwd
												16'h0000;				// This should never happen, the compiler just wants it

// Set pre_src0 to the direct output of the src0 mulitplexer
// This value will then (possibly) have some math done on it
assign pre_src0 =	(src0sel == A2D2Src0)		?	{4'b0000,A2D_res} :			// Zero-extended a2d_res
					(src0sel == Intgrl2Src0)	?	{{4{Intgrl[11]}},Intgrl} :	// Sign-extended Intgrl
					(src0sel == Icomp2Src0)		?	{{4{Icomp[11]}}, Icomp} :	// Sign-extended Icomp
					(src0sel == Pcomp2Src0)		?	Pcomp :						// Pcomp (already 16 bits wide)
					(src0sel == Pterm2Src0)		?	{2'b00,Pterm} :				// Zero-extended Pterm
													16'h0000;			// This should never happen, the compiler just wants it

// If mult2 is asserted, shift_src0 gets pre_src0 * 2 (computed using a left shift)
// Otherwise, if mult4 is asserted, shift_src0 gets pre_src0 * 4 (computed using a left shift of 2)
// If neither are asserted, shift_src0 just gets pre_src0
assign shift_src0 =	(mult2 == 1'b1) ? pre_src0 << 1 :
					(mult4 == 1'b1) ? pre_src0 << 2 : pre_src0;

// If sub is asserted, src0 gets the 1's compliment of shift_src0
// Otherwise, it just gets shift_src0
assign src0 = (sub == 1'b1) ? ~shift_src0 : shift_src0;



/**********************************
 * Adder and its Saturation Logic *
 **********************************/

// Add src1 and src0 together into add_result
// Also add sub so that subtraction does a 2's complement subtraction
assign {add_cout,add_result} = src1 + src0 + sub;

/* Now, we have to figure out what to saturate add_result to, assuming it needs to be saturated.
 * Since add_result could have overflowed, add_cout determines whether add_result truly should be positive or negative.
 * If add_cout is 1, then add_result is negative. Otherwise, it's positive.
 *
 * If add_result is positive, then the saturated value will be the lesser of add_result and 0x07FF.
 * If any of the top 5 bits in add_result are a 1, then add_result is greater than 0x07FF.
 * This can be found by nor-ing the top 5 bits of add_result, as the nor would output a 1 if there are no 0's.
 * Thus, if the nor of add_resut[15:11] outputs a 1, then add_results should be used.
 *
 * If add_result is negative, then the saturated value will be the greater of add_result and 0xF800.
 * If any of the top 5 bits in add_result are a 0, then add_result is less than 0xF800.
 * This can be found by nand-ing the top 5 bits of add_result, as the nand would output a 0 if there are any 0's.
 * Thus, if the nand of add_result[15:11] outputs a 0, then add_result should be used.
 */
assign add_sat_pos_val = ( ~|add_result[15:11] ) ? (add_result) : (16'h07FF);
assign add_sat_neg_val = ( ~&add_result[15:11] ) ? (16'hF800) : (add_result);
assign add_sat_final_val = (add_result[15]) ? (add_sat_neg_val) : (add_sat_pos_val);

// Finally, now that we have the answer and it's saturation value, we determine whether or not
// the ALU is supposed to even saturate the sum at all using the saturate input
assign add_final = (saturate) ? (add_sat_final_val) : (add_result);



/***************************************
 * Multiplier and its Saturation Logic *
 ***************************************/

// We want to multiply sign-extended src1[14:0] and src0[14:0], then divide by 4096.
// We will do the division when determining saturation (aka later).
assign mul_src1 = {src1[14], src1[14:0]};
assign mul_src0 = {src0[14], src0[14:0]};
assign mul_result = mul_src1 * mul_src0;

/* Now, we have to figure out what to saturate mul_result to.
 * Since we're dividing by 4096, and then saturating to a 15 bit result,
 * we only really care about mul_result[28:12].
 * However, mul_result[29] will determine if it is positive or negative.
 *
 * If mul_result is positive, then the saturated value will be the lesser of mul_result and 0x3FFF.
 * If mul_result[28:26] is not equal to 3'b000, then it will get saturated.
 * If the nor of those bits is a 1, then the saturation value 0x3FFF will be used.
 *
 * If mul_result is negative, then the saturated value will be the greater of mul_result and 0xC000.
 * If mul_result[28:26] is not equal to 3'b111, then it will get saturated.
 * If the nand of those bits is a 1, then the saturation value of 0xC000 will be used.
 */
assign mul_sat_pos_val = ( ~|mul_result[28:26] ) ? (mul_result[28:12]) : (16'h3FFF);
assign mul_sat_neg_val = ( ~&mul_result[28:26] ) ? (16'hC000) : (mul_result[28:12]);
assign mul_final = (mul_result[29]) ? (mul_sat_neg_val) : (mul_sat_pos_val);



/**********************
 * Final Answer Logic *
 **********************/

// Finally, we just determine whether the final answer should be the result
// from the adder or multiplier
assign dst = (multiply) ? (mul_final) : (add_final);

// That's all folks!
endmodule

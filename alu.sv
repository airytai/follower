// This is the alu Verilog for Line Follower implementation
module alu(Accum, Pcomp, Icomp, Pterm, Iterm, Fwd, A2D_res, Error, Intgrl, src0sel, src1sel, multiply, sub, mult2, mult4, saturate, dst);

    input signed [15:0] Accum, Pcomp; // Accum: Accum for error build-up; Pcomp: P component of PI control
    input [13:0] Pterm; // P term in the PI control
    /**
    * Icomp: I component of PI control; Iterm: I term in the PI control;
    * Fwd: determine forward spped; A2D_res: A2D converter; 
    * Error: error; Intgrl: intgrl;
    **/
    input signed [11:0] Icomp, Error, Intgrl;
    input [11:0] Iterm, Fwd, A2D_res;
    input [2:0] src0sel, src1sel; // input signal with 3 bit width, used for source selection in MUX 0 and 1

    /**
    * multiply: control 12x12 multiply; sub: control subtract src0;
    * mult2: control src0 multiplied by 2; mult4: control src0 multiplied by 4;
    * saturate: control saturation; 
    **/
    input multiply, sub, mult2, mult4, saturate; 
   
    output signed [15:0] dst; // result of ALU

    wire [1:0] scaled_src0; // The vector incorporates mult2 & mult4
    wire [15:0] inter_sum; // hold the adder of two src
    wire [15:0] result_sum; // saturate logic performed on inter_sum
    wire signed [29:0] inter_mul; // 30 bits to hold the value of 15x15 multiplication.
    wire [15:0] result_mul; // saturate logic performed on inter_mul
    wire [3:0] sat_check; // check used in 16-bit saturation logic

    wire [15:0] src0, src1; // hold the src value after selection 
    wire [15:0] pre_src1, pre_src0; // values of src0 and src1 after selection
    wire [15:0] modify_src0; // src0 signal after possible mult2, mult4
    wire signed [14:0] mul_src1, mul_src0; // trunk src1 and src0 for 15x15 multiplication

    // use src1sel to select from src1
    localparam Accum2Src1   = 3'b000;
    localparam Iterm2Src1   = 3'b001;
    localparam Err2Src1     = 3'b010;
    localparam ErrDiv22Src1 = 3'b011;
    localparam Fwd2Src1     = 3'b100;

    assign pre_src1[15:0] = (src1sel == Accum2Src1)   ? Accum                         :
                            (src1sel == Iterm2Src1)   ? {4'b0000, Iterm}              :
                            (src1sel == Err2Src1)     ? {{4{Error[11]}}, Error}        :
                            (src1sel == ErrDiv22Src1) ? {{8{Error[11]}}, Error[11:4]} :
                            (src1sel == Fwd2Src1)     ? {4'b0000, Fwd}                :
                                                        16'h0000; 

    // use src0sel to select from src0
    localparam A2D2Src0    = 3'b000;
    localparam Intgrl2Src0 = 3'b001;
    localparam Icomp2Src0  = 3'b010;
    localparam Pcomp2Src0  = 3'b011;
    localparam Pterm2Src0  = 3'b100;

    assign pre_src0[15:0] = (src0sel == A2D2Src0)    ? {4'b0000, A2D_res}        :
                            (src0sel == Intgrl2Src0) ? {{4{Intgrl[11]}}, Intgrl} :
                            (src0sel == Icomp2Src0)  ? {{4{Icomp[11]}}, Icomp}   :
                            (src0sel == Pcomp2Src0)  ? Pcomp                     :
                            (src0sel == Pterm2Src0)  ? {2'b00, Pterm}            :
                                                       16'h0000; 

    // src0 value has possibility of being left shifted by 1 or 2 bits (mult2 or mult4)
    assign scaled_src0 = {mult4, mult2}; // shift 2: 10, shift 1: 01, no shift: 00
    localparam NOMUL = 2'b00;
    localparam MULT2 = 2'b01;
    localparam MULT4 = 2'b10;

    assign modify_src0[15:0] = (scaled_src0 == NOMUL) ? pre_src0                 :
                               (scaled_src0 == MULT2) ? {pre_src0[14:0], 1'b0}   :
                               (scaled_src0 == MULT4) ? {pre_src0[13:0], 2'b00}  :
                                                        16'h0000 ;


    // ADDER OR SUBTRACTOR
    // If sub is enable, we subtract src0, otherwise we add
    assign inter_sum = sub ? (pre_src1 +(~modify_src0+1)) : (pre_src1 + modify_src0);

    /**
    * 12-bit saturate logic
    * if saturate is enable, we do saturation, otherwise we return the adder result
    * if (inter_sum[15] = 1) -> if (inter_sum < 16'hF800) -> 16'hF800
    *                           else                      -> inter_sum
    * elseif                 -> if (inter_sum > 16'h07FF) -> 16'h07FF
    *                           else                      -> inter_sum
    **/
    assign result_sum = (saturate) ? (   (inter_sum[15]) ? ( (inter_sum < 16'hF800) ? 16'hf800 : inter_sum ) 
                                                         : ( (inter_sum > 16'h07FF) ? 16'h07FF : inter_sum )    )
                                   : inter_sum ;


    /**
    * 15x15 multiply
    **/
    assign mul_src1 = pre_src1[14:0]; // get the signed value of src1
    assign mul_src0 = modify_src0[14:0]; // get the signed value of src0
    assign inter_mul = mul_src0[14:0] * mul_src1[14:0];
    /**
    * 16-bit saturate logic
    * if (inter_mul[29] = 1) -> if (inter_mul[28:26] == 3'b111) -> inter_mul[27:12]
    *                           else                            -> 16'hC000
    * elseif                 -> if (inter_mul[28:26] == 3'b000) -> inter_mul[27:12]
    *                           else                            -> 16'h3FFF
    **/
    
    
    assign sat_check = inter_mul[29:26];
    assign result_mul = (inter_mul[29]) ? ((inter_mul[28:26] == 3'b111) ? inter_mul[27:12] : 16'hC000) :
                                          ((inter_mul[28:26] == 3'b000) ? inter_mul[27:12] : 16'h3FFF) ;

    // DST MUX
    assign dst = (multiply) ? result_mul : result_sum;

endmodule
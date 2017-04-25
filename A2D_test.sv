module A2D_test(clk,RST_n,nxt_chnnl,LEDs);

input clk,RST_n;		// 50MHz clock and active low unsynchronized reset from push button
input nxt_chnnl;		// unsynchronized push button.  Advances to convert next chnnl
output [7:0] LEDs;		// upper bits of conversion displayed on LEDs
wire a2d_SS_n;		// Active low slave select to A2D (part of SPI bus)
wire MOSI;			// Master Out Slave In to A2D (part of SPI bus)
wire MISO;				// Master In Slave Out from A2D (part of SPI bus)
wire SCLK;			// Serial clock of SPI bus

/* 
module A2D_test(clk,RST_n,nxt_chnnl,LEDs, a2d_SS_n, MOSI, MISO, SCLK);
input clk,RST_n;		// 50MHz clock and active low unsynchronized reset from push button
input nxt_chnnl;		// unsynchronized push button.  Advances to convert next chnnl
output [7:0] LEDs;		// upper bits of conversion displayed on LEDs
input a2d_SS_n;		// Active low slave select to A2D (part of SPI bus)
input MOSI;			// Master Out Slave In to A2D (part of SPI bus)
output MISO;				// Master In Slave Out from A2D (part of SPI bus)
input SCLK;			// Serial clock of SPI bus
*/

///////////////////////////////////////////////////
// Declare any registers or wires you need here //
/////////////////////////////////////////////////
wire [11:0] res;		// result of A2D conversion
wire rst_n;
reg [2:0] chnnl;
reg strt_cnv;
wire cnv_cmplt;


/////////////////////////////////////
// Instantiate Reset synchronizer //
///////////////////////////////////
reset_synch iRST(.clk(clk), .RST_n(RST_n), .rst_n(rst_n));

////////////////////////////////
// Instantiate A2D Interface //
//////////////////////////////
A2D_intf iA2D(.clk(clk), .rst_n(rst_n), .strt_cnv(strt_cnv), .cnv_cmplt(cnv_cmplt), .chnnl(chnnl),
              .res(res), .a2d_SS_n(a2d_SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));


////////////////////////////////////////
// Synchronize nxt_chnnl push button //
//////////////////////////////////////
reg flop_q1, flop_q2, flop_q3;
wire falledge; // falledge is asserted when falling edge is detected

always@(posedge clk or negedge rst_n)
        begin
        if(!rst_n)
            flop_q1 <= 1'b1;
        else begin
            flop_q1 <= nxt_chnnl;
            flop_q2 <= flop_q1;
            flop_q3 <= flop_q2;
        end
end
assign falledge = flop_q2 & !flop_q3; 
    
 
///////////////////////////////////////////////////////////////////
// Implement method to increment channel and start a conversion //
// with every release of the nxt_chnnl push button.            //
////////////////////////////////////////////////////////////////
always@(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
        chnnl <= 1'b0;
        strt_cnv <= 1'b0;
    end
    else if (falledge) begin
        chnnl <= chnnl + 1'b1;
        strt_cnv <= 1'b1;
    end else begin
        chnnl <= chnnl;
        strt_cnv <= 1'b0; // if no falledge, start back to 0, asserted for 1 cycle
    end
end

//////////////////////////////////////////////////////////
// Demo 1: ADC128S                                      //
//////////////////////////////////////////////////////////

ADC128S  ADC128S_0(.clk(clk), .rst_n(rst_n), .SS_n(a2d_SS_n), .SCLK(SCLK), .MISO(MISO), .MOSI(MOSI));


//////////////////////////////////////////////////////////////////////////
// Demo 2: ADC128S                                           			//
// Modify this file and .qsf to connect to the physical ADC. 			//
// - Remove the instantiation of ADC128S.                   			//
// - Add SPI ports to the top module and map them to pins in .qsf file. //
//////////////////////////////////////////////////////////////////////////

	
assign LEDs = res[11:4];

endmodule
    

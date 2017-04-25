module A2D_intf_tb();

    logic clk,rst_n;			// 50MHz clock and active low asynch reset
    logic strt_cnv;			// initiates an A2D conversion
    logic [2:0] chnnl;		// channel to perform conversion on
    logic MISO;				// Serial logic from A2D (Master In Slave Out)
    logic [11:0] res;		// result of A2D conversion
    logic cnv_cmplt;			// indicates full round robin conversions is complete
    logic a2d_SS_n;			// active low SPI slave select to A2D
    logic SCLK,MOSI;			// SPI master signals
    reg [3:0] chnnl_cnt;    // used to loop chnnl, 4th bit for escape the loop
    reg tigger;   // used for very first conversation trigger

    A2D_intf iDUT_A2D_intf( .clk(clk), .rst_n(rst_n), .strt_cnv(strt_cnv), .cnv_cmplt(cnv_cmplt), .chnnl(chnnl), .res(res), .a2d_SS_n(a2d_SS_n), .SCLK(SCLK), .MOSI(MOSI), .MISO(MISO));
    ADC128S iDUT_ADC128S( .clk(clk), .rst_n(rst_n), .SS_n(a2d_SS_n), .SCLK(SCLK), .MISO(MISO), .MOSI(MOSI));

    initial $monitor("%t, rst_n: %d, strt_cnv: %d, cnv_cmplt: %d, SCLK: %d, a2d_SS_n: %d, MOSI: %d, MISO: %d, chnnl: %d, res: %d", $time, rst_n, strt_cnv, cnv_cmplt, SCLK, a2d_SS_n, MOSI, MISO, chnnl, res);

    always #10 clk = ~clk;
    assign chnnl = chnnl_cnt[2:0];

    always@(posedge clk, negedge rst_n) begin
        if(!rst_n)
            chnnl_cnt <= 0; // 
        else if(iDUT_ADC128S.rdy_rise)
            chnnl_cnt <= chnnl_cnt + 1;
    end
    
    initial begin
        rst_n = 1'b0;
        clk = 1'b0;
        repeat(1'b1)@(posedge clk);// asserted for 1 clk
        rst_n = 1'b1; // at pose edge
        tigger = 1'b1;
        repeat(1'b1)@(posedge clk);// asserted for 1 clk
        tigger = 1'b0;
	repeat(4896)@(posedge clk);// wait for another 17*32*9 clk, 17 SCLK, count 9 ch
	$stop;
    end
    
    always@(posedge clk, negedge rst_n) 
        if(!rst_n)
            strt_cnv = 1'b0;
	else if(iDUT_ADC128S.rdy_rise || tigger)
            strt_cnv = 1'b1;
        else
            strt_cnv = 1'b0;

endmodule
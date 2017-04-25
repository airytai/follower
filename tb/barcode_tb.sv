module barcode_tb();
    logic BC;
    logic clr_ID_vld, rst_n, clk, ID_vld;
    logic [7:0] ID;
    
    logic [21:0] period; // transmission period
    logic send; // asserted for 1 clock to initiate a transmission
    logic [7:0] station_ID; // code to transmit
    logic BC_done;
    initial $monitor("time: %t, BC: %d, clr_ID_vld: %d, ID_vld: %d, period: %d, send: %d, station_ID: %d, BC_done: %d", $time, BC, clr_ID_vld, ID_vld, period, send, station_ID, BC_done);

    // initialize clk
    always #10 clk = ~clk;

    // instantiate iDUT
    barcode iDUT(.BC(BC), .ID_vld(ID_vld), .ID(ID), .clr_ID_vld(clr_ID_vld), .rst_n(rst_n), .clk(clk));
    // instantiate mimic
    barcode_mimic iDUT_mimic(.clk(clk),.rst_n(rst_n),.period(period),.send(send),.station_ID(station_ID),.BC_done(BC_done),.BC(BC));

    initial begin
        rst_n = 1'b0;
        clk = 1'b0;
        period = 22'h004000; // 00_0000_0100_0000_0000_00000
	station_ID = 8'h35; // 0011_0101
        repeat(1'b1)@(posedge clk);// asserted for half clk
        rst_n = 1; // deasserted to let the test start
        send = 1'b1; // initiate a transmission
        clr_ID_vld = 1'b1;
        repeat(1'b1)@(posedge clk);// asserted for 1 clk
        send = 1'b0;
        clr_ID_vld = 1'b0;
        
    end

	always@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			clr_ID_vld = 1'b0;
		else if(BC_done) begin // finish transmission
            		clr_ID_vld = 1'b1;
            		repeat(8'hFF)@(posedge clk);// wait to stop
            		$stop;
       		end
	end

endmodule

module SPI_mstr_tb();

    

    logic clk, rst_n, wrt;
    logic [15:0] cmd;
    logic done;
    logic [15:0] rd_data;
    logic SS_n;
    logic SCLK, MOSI;
    logic MISO;
    logic rdy;

    SPI_mstr iDUT_master( .clk(clk), .rst_n(rst_n), .wrt(wrt), .cmd(cmd), .done(done), .rd_data(rd_data), .SCLK(SCLK), .SS_n(SS_n), .MOSI(MOSI), .MISO(MISO));
    SPI_slave iDUT_slave( .clk(clk), .rst_n(rst_n), .SS_n(SS_n), .SCLK(SCLK), .MISO(MISO), .MOSI(MOSI), .rdy(rdy));
    
    initial $monitor("%t, rst_n: %d, wrt: %d, done: %d, SCLK: %d, SS_n: %d, MOSI: %d, MISO: %d", $time, rst_n, wrt, done, SCLK, SS_n, MOSI, MISO);

    always #10 clk = ~clk;

    initial begin
        rst_n = 1'b0;
        clk = 1'b0;
        repeat(1'b1)@(posedge clk);// asserted for 1 clk, clk low
        rst_n = 1'b1; // at pose edge
        wrt = 1'b1;
        cmd = 16'b0110_0011_1010_1100;
        repeat(1'b1)@(posedge clk);// asserted for 1 clk, clk low
        wrt = 1'b0;
        repeat(19'hF0A0)@(posedge clk);// wait for 17 SCLK
        
        repeat(19'hF0A0)@(posedge clk);// wait for 17 SCLK
        // test send back if last one ok
        // repeat(19'hF0A0)@(posedge clk);// wait for 17 SCLK

        $stop;

    end

endmodule
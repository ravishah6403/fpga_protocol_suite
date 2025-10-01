module SPI_Master_TB ();

parameter SPI_MODE = 3;
parameter CLKS_PER_HALF_BIT = 4;
parameter MAIN_CLK_DELAY = 2;

logic r_Rst_L = 1'b0;
logic w_SPI_Clk;
logic r_Clk = 1'b0;
logic w_SPI_MOSI;

logic [7:0] r_Master_TX_Byte = 0;
logic r_Master_TX_DV = 1'b0;
logic w_Master_TX_Ready;
logic r_Master_RX_DV;
logic [7:0] r_Master_RX_Byte;

always #(MAIN_CLK_DELAY) r_Clk = ~r_Clk;

SPI_Master
#(
    .SPI_MODE(SPI_MODE),
    .CLKS_PER_HALF_BIT(CLKS_PER_HALF_BIT)
)
SPI_Master_UUT
(
    .i_Rst_L(r_Rst_L),
    .i_Clk(r_Clk),

    .i_TX_Byte(r_Master_TX_Byte),
    .i_TX_DV(r_Master_TX_DV),
    .o_TX_Ready(w_Master_TX_Ready),

    .o_RX_DV(r_Master_RX_DV),
    .o_RX_Byte(r_Master_RX_Byte),

    .o_SPI_Clk(w_SPI_Clk),
    .i_SPI_MISO(w_SPI_MOSI),
    .o_SPI_MOSI(w_SPI_MOSI)
);

// Sends a single byte from master
task SendSingleByte(input [7:0] data);
@(posedge r_Clk);
r_Master_TX_Byte <= data;
r_Master_TX_DV <= 1'b1;

@(posedge r_Clk);
r_Master_TX_DV <= 1'b0;

@(posedge w_Master_TX_Ready);
endtask

initial 
begin
    $dumpfile("dump.vcd"); 
    $dumpvars;

    repeat(10) @(posedge r_Clk);
    r_Rst_L = 1'b0;
    repeat(10) @(posedge r_Clk);
    r_Rst_L = 1'b1;

    SendSingleByte(8'hC1);
    $display("Sent out 0xC1m Received 0x%X", r_Master_RX_Byte);

    SendSingleByte(8'hBE);
    $display("Sent out 0xBE, Received 0x%X", r_Master_RX_Byte); 
    SendSingleByte(8'hEF);
    $display("Sent out 0xEF, Received 0x%X", r_Master_RX_Byte); 
    repeat(10) @(posedge r_Clk);
    $finish();
    
end

endmodule
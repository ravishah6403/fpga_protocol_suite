module Nokia5110_Test
(
    input        i_Clk,
    input        i_Rst_L,
    output       o_SPI_Clk,
    output       o_SPI_MOSI,
    output reg   o_LCD_DC,
    output reg   o_LCD_RST,
    output reg   o_LCD_CE
);

    // Instantiate SPI Master (Mode 0, slow clock)
    wire        w_TX_Ready;
    reg         r_TX_DV;
    reg  [7:0]  r_TX_Byte;
    wire        w_RX_DV;
    wire [7:0]  w_RX_Byte;

    SPI_Master #(
        .SPI_MODE(0),
        .CLKS_PER_HALF_BIT(25)   // adjust based on FPGA clock for ~400kHz–1MHz SPI
    ) SPI0 (
        .i_Rst_L(i_Rst_L),
        .i_Clk(i_Clk),
        .i_TX_Byte(r_TX_Byte),
        .i_TX_DV(r_TX_DV),
        .o_TX_Ready(w_TX_Ready),
        .o_RX_DV(w_RX_DV),
        .o_RX_Byte(w_RX_Byte),
        .o_SPI_Clk(o_SPI_Clk),
        .i_SPI_MISO(1'b0),   // LCD has no MISO
        .o_SPI_MOSI(o_SPI_MOSI)
    );

    reg [7:0] screenBuffer [503:0];

    // Simple FSM for sending init + data
    reg [7:0] r_State;
    reg [15:0] r_Counter;

    initial $readmemh("image.hex", screenBuffer);

    always @(posedge i_Clk or negedge i_Rst_L) begin
        if (!i_Rst_L) begin
            r_State   <= 0;
            r_Counter <= 0;
            r_TX_DV   <= 0;
            r_TX_Byte <= 8'h00;
            o_LCD_RST <= 0;   // hold in reset
            o_LCD_CE  <= 1;   // not selected
            o_LCD_DC  <= 0;   // command mode
        end else begin
            case (r_State)

            // Hold reset for some time
            0: begin
                o_LCD_RST <= 0;
                r_Counter <= r_Counter + 1;
                if (r_Counter == 16'h0FFF) begin
                    r_Counter <= 0;
                    r_State <= 1;
                end
            end

            // Release reset
            1: begin
                o_LCD_RST <= 1;
                r_State   <= 2;
            end

            // Send init command (example: function set)
            2: begin
                if (w_TX_Ready) begin
                    o_LCD_CE <= 0;
                    o_LCD_DC <= 0;     // command
                    r_TX_Byte <= 8'h21; // extended command mode
                    r_TX_DV   <= 1;
                    r_State   <= 3;
                end
            end

            3: begin
                r_TX_DV <= 0;
                if (w_TX_Ready) r_State <= 4;
            end

            // Example: set contrast
            4: begin
                if (w_TX_Ready) begin
                    r_TX_Byte <= 8'hB1; // contrast
                    r_TX_DV   <= 1;
                    r_State   <= 5;
                end
            end

            5: begin
                r_TX_DV <= 0;
                if (w_TX_Ready) r_State <= 6;
            end

            // Switch back to basic command mode
            6: begin
                if (w_TX_Ready) begin
                    r_TX_Byte <= 8'h20; // basic command set
                    r_TX_DV   <= 1;
                    r_State   <= 7;
                end
            end

            7: begin
                r_TX_DV <= 0;
                if (w_TX_Ready) r_State <= 8;
            end

            // Set display control = normal mode
            8: begin
                if (w_TX_Ready) begin
                    r_TX_Byte <= 8'h0C; // normal display
                    r_TX_DV   <= 1;
                    r_State   <= 9;
                end
            end

            9: begin
                r_TX_DV <= 0;
                if (w_TX_Ready) r_State <= 10;
            end

            10: begin
                if (w_TX_Ready) begin
                    o_LCD_DC  <= 0;     // command mode
                    r_TX_Byte <= 8'h80; // set X=0
                    r_TX_DV   <= 1;
                    r_State   <= 11;
                end
            end

            11: begin
                r_TX_DV <= 0;
                if (w_TX_Ready) r_State <= 12;
            end

            12: begin
                if (w_TX_Ready) begin
                    r_TX_Byte <= 8'h40; // set Y=0
                    r_TX_DV   <= 1;
                    r_State   <= 13;
                end
            end

            13: begin
                r_TX_DV <= 0;
                if (w_TX_Ready) r_State <= 14;
            end

            // Send test pattern (data)
            14: begin
                if (w_TX_Ready) begin
                    o_LCD_DC  <= 1;    // data mode
                    r_TX_Byte <= screenBuffer[r_Counter];
                    r_TX_DV   <= 1;
                    r_State   <= 15;
                end
            end

            15: begin
                r_TX_DV <= 0;
                if (w_TX_Ready) begin
                    r_Counter <= r_Counter + 1;
                    if (r_Counter < 504) begin // 84x48 pixels / 8 = 504 bytes
                        r_State <= 14; // keep writing
                    end else begin
                        r_State <= 16;
                    end
                end
            end

            // Done
            16: begin
                o_LCD_CE <= 1; // disable LCD
            end

            default: r_State <= 0;
            endcase
        end
    end

endmodule

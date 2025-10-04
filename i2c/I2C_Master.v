module I2C_Master (
    input i_Clk,
    input i_Rst,
    input [6:0] i_Addr,
    input [7:0] i_TX_Data,
    input i_Enable,
    input i_RW,

    output reg [7:0] o_RX_Data,
    output wire o_Ready,

    inout ino_SDA,
    inout wire ino_SCL
);

    localparam IDLE = 0;
    localparam START = 1;
    localparam ADDRESS = 2;
    localparam READ_ACK = 3;
    localparam WRITE_DATA = 4;
    localparam WRITE_ACK = 5;
    localparam READ_DATA = 6;
    localparam READ_ACK2 = 7;
    localparam STOP = 8;

    localparam DIVIDE_BY = 4;

    reg [3:0] r_State;
    reg [7:0] r_Saved_Addr;
    reg [7:0] r_Saved_Data;
    reg [7:0] r_Counter;
    reg [7:0] r_Counter2 = 0;
    reg r_Write_Enable;
    reg r_SDA_Out;
    reg r_I2C_SCL_Enable = 0;
    reg r_I2C_Clk = 1;

    assign o_Ready = ((i_Rst == 0) && (r_State == IDLE)) ? 1 : 0;
    assign ino_SCL = (r_I2C_SCL_Enable == 0) ? 1 : r_I2C_Clk;
    assign ino_SDA = (r_Write_Enable == 1) ? r_SDA_Out : 1'bz;

    always @(posedge i_Clk) begin
        if (r_Counter2 == (DIVIDE_BY/2) - 1) begin
            r_I2C_Clk <= ~r_I2C_Clk;
            r_Counter2 <= 0;
        end

        else r_Counter2 <= r_Counter2 + 1;
    end

    always @(negedge r_I2C_Clk, posedge i_Rst) begin
        if (i_Rst == 1) r_I2C_SCL_Enable <= 0;

        else begin
            if ((r_State == IDLE) || (r_State == START) || (r_State == STOP)) r_I2C_SCL_Enable <= 0;
            else r_I2C_SCL_Enable <= 1;
        end
    end

  always @(posedge r_I2C_Clk, posedge i_Rst) begin
    if (i_Rst == 1) r_State <= IDLE;

        else begin
            case (r_State)

                IDLE : begin
                    if (i_Enable) begin
                        r_State <= START;
                        r_Saved_Addr <= {i_Addr, i_RW};
                        r_Saved_Data <= i_TX_Data;
                    end
                    
                    else r_State <= IDLE;
                end

                START : begin
                    r_Counter <= 7;
                    r_State <= ADDRESS;
                end

                ADDRESS : begin
                    if (r_Counter == 0) r_State <= READ_ACK;
                    else r_Counter <= r_Counter - 1;
                end

                READ_ACK : begin
                    if (ino_SDA == 0) begin
                        r_Counter <= 7;
                        if (r_Saved_Addr[0] == 0) r_State <= WRITE_DATA;
                        else r_State <= READ_DATA;
                    end

                    else r_State <= STOP;
                end

                WRITE_DATA : begin
                    if (r_Counter == 0) r_State <= READ_ACK2;
                    else r_Counter <= r_Counter - 1;
                end

                READ_ACK2 : begin
                    if ((ino_SDA == 0) && (i_Enable == 1)) r_State <= IDLE;
                    else r_State <= STOP;
                end

                READ_DATA : begin
                    o_RX_Data[r_Counter] <= ino_SDA;
                    if (r_Counter == 0) r_State <= WRITE_ACK;
                    else r_Counter <= r_Counter - 1;
                end

                WRITE_ACK : begin
                    r_State <= STOP;
                end

                STOP : begin
                    r_State <= IDLE;
                end

            endcase
        end        
    end

    always @(negedge r_I2C_Clk, posedge i_Rst) begin
        if (i_Rst == 1) begin
            r_Write_Enable <= 1;
            r_SDA_Out <= 1;
        end

        else begin
            case (r_State)

                START : begin
                    r_Write_Enable <= 1;
                    r_SDA_Out <= 0;
                end

                ADDRESS : r_SDA_Out <= r_Saved_Addr[r_Counter];

                READ_ACK : r_Write_Enable <= 0;

                WRITE_DATA : begin
                    r_Write_Enable <= 1;
                    r_SDA_Out <= r_Saved_Data[r_Counter];
                end

                WRITE_ACK : begin
                    r_Write_Enable <= 1;
                    r_SDA_Out <= 0;
                end

                READ_DATA : r_Write_Enable <= 0;

                STOP : begin
                    r_Write_Enable <= 1;
                    r_SDA_Out <= 1;
                end

            endcase
        end
    end
    
endmodule
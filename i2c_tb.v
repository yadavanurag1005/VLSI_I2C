`timescale 1ns / 1ps


module i2c_tb();
reg clk;
reg reset;
reg rw;
reg [7:0] data_in;
reg [6:0] addr;
reg [7:0] block_addr;
reg enable; 
wire [7:0] data_out;
wire busy;
wire scl;
wire sda;

i2c_master master_uut(
                      .clk(clk),
                      .reset(reset),
                      .rw(rw),
                      .data_in(data_in),
                      .addr(addr),
                      .block_addr(block_addr),
                      .enable(enable),
                      .data_out(data_out),
                      .busy(busy),
                      .scl(scl),
                      .sda(sda));
           
i2c_slave slave_uut(
                     .sda(sda),
                     .scl(scl),
                     .reset(reset));

always begin
#5 clk = ~clk;
end

initial begin
clk = 0;
reset = 1;
#5000;
reset = 0;
data_in = 8'b10010101;
addr = 7'b1101001;
block_addr = 8'b10001101;
rw = 0;
enable = 1;
#5000;
enable = 0;

wait(!busy);
//reset = 1;
#5000;
//reset = 0;
addr = 7'b1101001;
block_addr = 8'b10001101;
rw = 1;
enable = 1;
#5000;
enable = 0;
wait(!busy);
#5000 $finish;
end

endmodule

`timescale 1ns / 1ps


module i2c_master(
input clk,
input reset,
input rw,
input [7:0] data_in,
input [6:0] addr,
input [7:0] block_addr,
input enable, //start signal
output reg [7:0] data_out,
output reg ack,
output busy,
output scl,
inout sda
    );
    
parameter idle = 4'b0000, //0
          start_0 = 4'b0001, //1
          addr_0 = 4'b0010, //2
          read_ack_0 = 4'b0011, //3
          int_reg_addr = 4'b0100, //4
          read_ack_2 = 4'b0101, //5
          data_tx = 4'b0110, //6
          read_ack_3 = 4'b0111, //7
          start_1 = 4'b1000, //8 repeated start
          addr_1 = 4'b1001, //9
          read_ack_1 = 4'b1010, //10
          data_rx = 4'b1011, //11
          write_ack = 4'b1100, //12
          stop = 4'b1101, //13
          delay = 4'b1110; //14
          
// clk = 1GHz, i2c freq= 200KHz, scl freq= 400KHz
// i2c counter: 0.5*(100M/200K) =50M/200K =2.5*100 =250 => 8 bit counter
// scl counter: 0.5*(100M/400K) =50M/400K =1.25*100 =125 => 8 bit counter

reg scl_clk = 1'b0;
reg i2c_clk = 1'b0;
reg [3:0] state;
reg [7:0] count_scl = 8'd0;
reg [7:0] count_i2c = 8'd0;
reg [2:0] count = 3'b000;
reg scl_clk_en = 1'b0;
reg sda_en = 1'b0;
reg sda_out;

reg [7:0] saved_addr;
reg [7:0] saved_block_addr;
reg [7:0] saved_data;

//12c_clk generation
always@(posedge clk) begin
if(count_i2c==8'd249) begin
    i2c_clk <= ~i2c_clk;
    count_i2c <= 8'd0;
    end
else 
    count_i2c <= count_i2c +1;
end 
          
// scl_clk generation
always@(posedge clk) begin
if(count_scl==8'd124) begin
    scl_clk <= ~scl_clk;
    count_scl <= 8'd0;
    end
else
    count_scl <= count_scl +1;
end

// state logic for FSM
always@(posedge i2c_clk, posedge reset) begin
    saved_block_addr <= block_addr;
    saved_data  <= data_in;
if(reset)
    state <= idle;
else begin
    case(state)
        idle: begin
              if(enable)
                    state <= start_0;
              else 
                    state <= idle;
              end
       start_0: begin
                    state <= addr_0;
                    saved_addr <= {addr, 1'b0};
                    count <= 3'd7;
                end
       addr_0: begin
                if(count == 3'd0)  state <= read_ack_0;
                else begin
                    count <= count-1;
                    state <= addr_0;
                     end
               end 
       read_ack_0: begin
                    if(sda==1'b0) begin
                                ack <= 1'b0;
                                state <= int_reg_addr;
                                count <= 3'd7;
                                end 
                    else begin 
                        ack <= 1'b1;
                        state <= stop;
                        end
                    end   
       int_reg_addr: begin
                       if(count==3'd0) state <= read_ack_2;
                       else begin
                            count <= count-1;
                            state <= int_reg_addr;
                            end
                       end
       read_ack_2: begin
                    if(sda==1'b0) begin
                                 ack <= 1'b0;
                                 if(rw) state <= delay;
                                 else begin
                                        state <= data_tx;
                                        count <= 3'd7;
                                        end
                                 end
                    else begin 
                        ack <= 1'b1;
                        state <= stop;
                        end
                    end 
       data_tx: begin
                    if(count == 3'd0)  state <= read_ack_3;
                    else begin
                         count <= count-1;
                         state <= data_tx;
                         end
                end
       read_ack_3: begin
                    if(sda==1'b0) begin
                                  state <= stop;
                                  ack <= 1'b0;
                                  end
                    else begin 
                        ack <= 1'b1;
                        state <= stop;
                        end
                    end 
       delay: begin
              state <= start_1;
              end
       //read
       start_1: begin
                saved_addr <= {addr,1'b1};
                state <= addr_1;
                count <= 3'd7;
                end
       addr_1: begin
                 if(count== 3'd0)  state <= read_ack_1;
                 else begin
                        count <= count-1;
                        state <= addr_1;
                        end
               end
       read_ack_1: begin
                   if(sda==1'b0) begin
                                ack <= 0;
                                count <= 3'd7;
                                state <= data_rx;
                                end
                   else begin 
                        ack <= 1'b1;
                        state <= stop;
                        end
                    end 
       data_rx: begin
                data_out[count] <= sda; 
                if(count==3'd0)  state <= write_ack;
                 else begin
                        count <= count-1;
                        state <= data_rx;
                        end
               end
       write_ack: begin
                  state <= stop;
                  ack <= 1'b0;
                  end
       stop: begin 
             //state <= stop;
             if(ack == 1'b1)    state <= stop;
             else state <= idle;
             end
       default: state <= idle;
    endcase
end
end

// scl_clk_en enabling clock scl
always@(negedge scl_clk, posedge reset) begin
if(reset) begin
    scl_clk_en <= 1'b0;
end
else begin
    if(state==idle || state==start_0 || state==start_1 || state==stop)
        scl_clk_en <= 1'b0;
    else 
        scl_clk_en <= 1'b1;
end
end

//sda enable logic
always@(negedge i2c_clk, posedge reset) begin
if(reset) begin
    sda_en <= 1'b1;
    sda_out <= 1'b1;
end
else begin
     case(state)
       idle: begin
                sda_en <= 1'b1;
                sda_out <= 1'b1;
                end
       start_0: begin
                sda_en <= 1'b1;
                sda_out <= 1'b0;
                end
       addr_0: begin
               sda_en <= 1'b1;
               sda_out <= saved_addr[count];
               end 
       read_ack_0: sda_en <= 1'b0;
              
       int_reg_addr: begin
                     sda_en <= 1'b1;
                     sda_out <= saved_block_addr[count];
                     end
       read_ack_2: sda_en <= 1'b0;
       data_tx: begin
                     sda_en <= 1'b1;
                     sda_out <= saved_data[count];
                end
       read_ack_3: sda_en <= 1'b0;
       delay: begin
              sda_en <= 1'b1;
              sda_out <= 1'b1;
              end
       //read
       start_1: begin
                sda_en <= 1'b1;
                sda_out <= 1'b0;
                end
       addr_1: begin
               sda_en <= 1'b1;
               sda_out <= saved_addr[count];
               end
       read_ack_1: sda_en <= 1'b0;
       data_rx: begin
                sda_en <= 1'b0;
               end
       write_ack: begin
                  sda_en <= 1'b1;
                  sda_out <= 1'b0;
                  end
       stop: begin
             sda_en <= 1'b1;
             sda_out <= 1'b1;
             end
       default: begin
             sda_en <= 1'b1;
             sda_out <= 1'b1;
             end
    endcase
    end
end

// output logics
assign sda = (sda_en==1'b1)? sda_out: 1'bz;
assign scl = (scl_clk_en==1'b1)? i2c_clk: 1'b1;
assign busy = (state==idle)? 1'b0: 1'b1;

endmodule

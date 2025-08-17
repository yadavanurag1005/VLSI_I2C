`timescale 1ns / 1ps


module i2c_slave(input scl,
                inout sda,
                input reset );
//states                
parameter read_start_0 = 4'b0000, //0
          addr_0 = 4'b0001, //1
          write_ack_0 = 4'b0010, //2
          int_reg_addr = 4'b0011, //3
          write_ack_2 = 4'b0100, //4
          read_start_1 = 4'b0101, //5
          data_rx = 4'b0110, //6
          write_ack_3 = 4'b0111, //7
          addr_1 = 4'b1000, //8
          write_ack_1 = 4'b1001, //9
          data_tx = 4'b1010, //10
          read_ack = 4'b1011, //11
          stop = 4'b1100; //12
          
localparam slave_addr = 7'b1101001; //slave address

reg [7:0] block_mem[255:0]; //internal registers

reg start_det = 1'b0;
reg stop_det = 1'b0;
reg [2:0] count = 3'b111;
reg [1:0] count_delay = 2'd3;
reg [3:0] state = addr_0;
reg [6:0] rx_addr;
reg [7:0] rx_block_addr;
reg [7:0] rx_data; 
reg [7:0] tx_data;

reg sda_out;
reg sda_en = 1'b0;

//start and stop detection
always@(sda) begin
if(sda==1'b0 && scl==1'b1)begin
                    start_det <= 1'b1;
                    stop_det <= 1'b0;
                    end
if(sda==1'b1 && scl==1'b1) begin
                    start_det <= 1'b0;
                    stop_det <= 1'b1;
                    end
case(state)
write_ack_0: begin
             start_det <= 0;
             stop_det <= 0;
             end
int_reg_addr: begin
              start_det <= 0;
              stop_det <= 0;
              end 
write_ack_2: begin
             start_det <= 0;
             stop_det <= 0;
             end
      
data_rx: begin
         start_det <= 0;
         stop_det <= 0;
         end
write_ack_3: begin
             start_det <= 0;
             stop_det <= 0;
             end
addr_1: begin
        start_det <= 0;
        stop_det <= 0;     
        end
write_ack_1: begin
             start_det <= 0;
             stop_det <= 0;             
             end
data_tx: begin
         start_det <= 0;
         stop_det <= 0;     
         end
read_ack: begin
          start_det <= 0;
          stop_det <= 0;
          end
stop: begin
      start_det <= 0;
      stop_det <= 0;
      end
endcase
end

//state fsm
always@(posedge scl, posedge reset) begin

if(stop_det==1'b1) begin
state <= stop;
end
if(reset) begin
state <= addr_0;
count <= 3'd7;
count_delay <= 2'd3;
end
else begin
case(state)
addr_0: begin
        if(start_det==1'b1) begin
        if(count==1'b0) state <= write_ack_0;
        else begin
             state <= addr_0;
             rx_addr[count-1] <= sda;
             count <= count-1;
             end
        end
        else begin 
             state <= addr_0;
             count <= 3'd7;
             count_delay <= 2'd3;
             end
        end
write_ack_0: begin
             if(rx_addr==slave_addr) 
                begin
                state <= int_reg_addr;
                count <= 3'd7;
                end
             else 
                state <= stop;
             end
int_reg_addr: begin
              rx_block_addr[count] <= sda;
              if(count==3'd0)  state <= write_ack_2;
              else begin
                   state <= int_reg_addr;
                   count <= count-1;
                   end
              end 
write_ack_2: begin
                 state <= read_start_1;
                 count <= 3'd7;
             end
read_start_1: begin
              if(start_det) begin
                            state <= addr_1;
                            count <= 3'd6;
                            count_delay <= 2'd3;
                            end
              else begin
                   if(count_delay==2'd1) begin
                   state <= data_rx;
                   rx_data[count] <= sda;
                   count <= count-1;
                   end
                   else begin
                   count_delay <= count_delay-1;
                   rx_data[count] <= sda;
                   count <= count-1;
                   state <= read_start_1;
                   end
                   end
              end
data_rx: begin
         rx_data[count] <= sda;
         if(count==3'd0) state <= write_ack_3;
         else begin
              state <= data_rx;
              count <= count-1;
              end
         end
write_ack_3: begin
             state <= addr_0;
             block_mem[rx_block_addr] <= rx_data;
             end
addr_1: begin
        tx_data <= block_mem[rx_block_addr];
        if(count==3'd0) state <= write_ack_1;
        else begin
             state <= addr_1;
             rx_addr[count-1] <= sda;
             count <= count-1;
             end       
        end
write_ack_1: begin
             if(rx_addr==slave_addr) 
                begin
                state <= data_tx;
                count <= 3'd7;
                end
             else 
                state <= stop;             
             end
data_tx: begin
         if(count==3'd0) state <= read_ack;
         else begin
              state <= data_tx;
              count <= count-1;
              end       
         end
read_ack: begin
          if(sda==1'b0) state <= addr_0;
          else state <= stop;
          end
stop: begin
      state <= addr_0;
      count <= 3'd7;
      count_delay <= 2'd3;
      end
default: begin state <= addr_0;
         count <= 3'd7;
         count_delay <= 2'd3;
         end
endcase
end
end

//sda enable
always@(negedge scl, posedge reset) begin
if(reset) begin
sda_en <= 1'b0;
end
else begin
case(state)
addr_0: begin
        sda_en <= 1'b0;
        end
write_ack_0: begin
             if(rx_addr==slave_addr) 
                begin
                sda_en <= 1'b1;
                sda_out <= 1'b0;
                end
             else begin
                sda_en <= 1'b1;
                sda_out <= 1'b1;
                 end
             end
int_reg_addr: begin
              sda_en <= 1'b0;
              end 
write_ack_2: begin
                 sda_en <= 1'b1;
                 sda_out <= 1'b0;
             end
read_start_1: begin
                sda_en <= 1'b0;
              end
data_rx: begin
                sda_en <= 1'b0;
         end
write_ack_3: begin
                 sda_en <= 1'b1;
                 sda_out <= 1'b0;
             end
addr_1: begin
        sda_en <= 1'b0;
        end
write_ack_1: begin
             if(rx_addr==slave_addr) 
                begin
                 sda_en <= 1'b1;
                 sda_out <= 1'b0;                
                 end
             else begin
                  sda_en <= 1'b1;
                  sda_out <= 1'b1; 
                  end           
             end
data_tx: begin
         sda_en <= 1'b1;
         sda_out <= tx_data[count];     
         end
read_ack: sda_en <= 1'b0;
stop: sda_en <= 1'b0;
default: sda_en <= 1'b0;
endcase
end
end

assign sda = (sda_en==1'b1)? sda_out: 1'bz;

endmodule

`timescale 1ns / 1ps

module Slave(
    input  wire clk,
    input  wire rst,
    inout  wire sda,
	 output reg [3:0] ledice,
	 input [2:0] sw_adr,
	 output [3:0] sadrzaj_mem,
    input  wire scl
);

  parameter [6:0] SLAVE_ADDR = 7'b1111111;

  localparam IDLE             		= 4'd0,
             RECEIVE_ADDR    			= 4'd1,
             ACK_ADDR         		= 4'd2,      
             WAIT_ACK_ADDR   		   = 4'd3, 
				 REC_MEM_ADDR				= 4'd4,
				 ACK_MEM_ADDR     		= 4'd5,
             WAIT_ACK_MEM_ADDR		= 4'd6,				 
             RECEIVE_DATA     		= 4'd7,
             ACK_WRITE        		= 4'd8,      
             WAIT_ACK_WRITE   		= 4'd9,    
             SEND_DATA        		= 4'd10,      
             WAIT_MASTER_ACK  		= 4'd11,     
             STOP             		= 4'd12;
            
  reg [3:0] state; 
  reg [2:0] bit_count; 
  reg [7:0] shift_reg; 

  reg [7:0] tx_buffer; 

  reg sda_oe;
  reg sda_out; 
  assign sda = sda_oe ? (sda_out ? 1'b1 : 1'b0) : 1'bz;

  reg sda_sync, scl_sync; 
  reg sda_prev, scl_prev; 

	reg [7:0] slave_mem [7:0]; 
	reg rw;							
	reg  [7:0] mem_addr_reg;	
	
	assign sadrzaj_mem = slave_mem[sw_adr];

	
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      sda_sync <= 1;
      scl_sync <= 1;
      sda_prev <= 1;
      scl_prev <= 1;
    end else begin
      sda_prev <= sda_sync;
      sda_sync <= sda;     
      scl_prev <= scl_sync;  
      scl_sync <= scl;     
    end
  end

  wire scl_rising  = (~scl_prev) & scl_sync;
  wire scl_falling = scl_prev & (~scl_sync);
  wire sda_falling = (sda_prev == 1'b1) && (sda_sync == 1'b0);
  wire sda_rising  = (sda_prev == 1'b0) && (sda_sync == 1'b1);

  wire start_cond = (scl_sync == 1'b1) && sda_falling;
  wire stop_cond  = (scl_sync == 1'b1) && sda_rising;

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      state <= IDLE;
      bit_count <= 0;
      shift_reg <= 0;
		mem_addr_reg <= 0; 
		tx_buffer <= 0;
      sda_oe <= 0;
    end else begin
      case (state)
        IDLE: begin
			 ledice[0] <= 1;
		    ledice[1] <= 0;
		    ledice[2] <= 0;
		    ledice[3] <= 0;
			 sda_oe <= 0;
			 shift_reg <= 0;
			 tx_buffer <= 0;
			 mem_addr_reg <= 0;
          if (start_cond) begin
            state <= RECEIVE_ADDR;
            bit_count <= 7; 
            end
        end

        RECEIVE_ADDR: begin
			 ledice[0] <= 0;
			 ledice[1] <= 1;
          if (scl_rising) begin
            shift_reg[bit_count] <= sda_sync;
            if (bit_count == 0)
              state <= ACK_ADDR;
            else
              bit_count <= bit_count - 1;
          end else begin
				state <= RECEIVE_ADDR;
			 end
        end

        ACK_ADDR: begin
				ledice[0] <= 1;
				ledice[1] <= 1;
				if ((shift_reg[7:1] != SLAVE_ADDR) && scl_rising) begin
				  sda_oe <= 1; 
				  sda_out <= 1;  
				  state <= IDLE;
				end else if ((shift_reg[7:1] == SLAVE_ADDR) && scl_rising) begin
				  rw <= shift_reg[0];
				  sda_oe <= 1; 
				  sda_out <= 0; 
				  state <= WAIT_ACK_ADDR;
				end else begin
				  state <= ACK_ADDR;
				end
		  end
		  
		  WAIT_ACK_ADDR: begin
			 ledice[0] <= 0;
			 ledice[1] <= 0;
			 ledice[2] <= 1;
          if(scl_falling) begin
            sda_oe <= 0; 
				state <= REC_MEM_ADDR;
            bit_count <= 7; 
          end else begin
				state <= WAIT_ACK_ADDR;
			 end
        end
		  
			REC_MEM_ADDR: begin
			 ledice[0] <= 1;
			 ledice[1] <= 0;
			 ledice[2] <= 1;
          if (scl_rising) begin
            mem_addr_reg[bit_count] <= sda_sync;
            if (bit_count == 0)
              state <= ACK_MEM_ADDR;
            else
              bit_count <= bit_count - 1;
			 end else begin
				state <= REC_MEM_ADDR;
			 end
        end
		  
		  ACK_MEM_ADDR: begin
			   ledice[0] <= 0;
				ledice[1] <= 1;
				ledice[2] <= 1;
				if (scl_rising && mem_addr_reg < 8) begin
				  sda_oe <= 1;
				  sda_out <= 0;  
				  state <= WAIT_ACK_MEM_ADDR;
				end else if (scl_rising && mem_addr_reg > 8) begin
				  sda_oe <= 1; 
				  sda_out <= 1; 
				  state <= IDLE;
				end else begin
				  state <= ACK_MEM_ADDR;
				end
		  end
		  
		  WAIT_ACK_MEM_ADDR: begin
			 ledice[0] <= 1;
			 ledice[1] <= 1;
			 ledice[2] <= 1;
          if(scl_falling) begin
            sda_oe <= 0; 
            if(rw == 1'b1) begin
              state <= SEND_DATA;
				  tx_buffer <= slave_mem[mem_addr_reg];
            end else
              state <= RECEIVE_DATA;
            bit_count <= 7;
          end else begin
				state <= WAIT_ACK_MEM_ADDR;
			 end
        end
		  
        RECEIVE_DATA: begin
			 ledice[0] <= 0;
			 ledice[1] <= 0;
			 ledice[2] <= 0;
			 ledice[3] <= 1;
          if (scl_rising) begin
            shift_reg[bit_count] <= sda_sync;
            if (bit_count == 0) begin
				  slave_mem[mem_addr_reg] <= {shift_reg[7:1], sda_sync};
              state <= ACK_WRITE;
            end else begin
              bit_count <= bit_count - 1;
            end
          end else begin
				state <= RECEIVE_DATA;
			 end
        end
		  
		  ACK_WRITE: begin
			 ledice[0] <= 1;
			 ledice[1] <= 0;
			 ledice[2] <= 0;
			 ledice[3] <= 1;
          if(scl_rising) begin
            sda_oe <= 1;
				sda_out <= 0; 
            state <= WAIT_ACK_WRITE;
          end else begin
				state <= ACK_WRITE;
			 end
        end
		  
		  WAIT_ACK_WRITE: begin
			 ledice[0] <= 0;
			 ledice[1] <= 1;
			 ledice[2] <= 0;
			 ledice[3] <= 1;
          if(scl_falling) begin
            sda_oe <= 0;
            state <= STOP;
          end else begin
				state <= WAIT_ACK_WRITE;
			 end
        end

        SEND_DATA: begin
			 ledice[0] <= 1;
			 ledice[1] <= 1;
			 ledice[2] <= 0;
			 ledice[3] <= 1;
          if (scl_rising) begin
			   if (tx_buffer[bit_count] == 1'b0) begin
					sda_oe <= 1;
					sda_out <= 0; 
            end else begin
					sda_oe <= 1; 
					sda_out <= 1; 
            end if (bit_count == 0)
              state <= WAIT_MASTER_ACK;
            else
              bit_count <= bit_count - 1;
          end else begin
				state <= SEND_DATA;
			 end
        end
		  
		  WAIT_MASTER_ACK: begin
			 ledice[0] <= 0;
			 ledice[1] <= 0;
			 ledice[2] <= 1;
			 ledice[3] <= 1;
			 if(scl_falling)
				sda_oe <= 0;
				state <= WAIT_MASTER_ACK;
          if (scl_rising) begin
            if (sda_sync == 1'b0) 
              state <= STOP;
            else 
              state <= IDLE;
          end else begin
				state <= WAIT_MASTER_ACK;
			 end
        end

        STOP: begin
			 ledice[0] <= 1;
			 ledice[1] <= 0;
			 ledice[2] <= 1;
			 ledice[3] <= 1;
          if (stop_cond) begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule

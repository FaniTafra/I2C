`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:14:56 10/02/2024 
// Design Name: 
// Module Name:    Master 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Master(
	 input wire clk,
    input wire rst,
    input wire en,
    input wire rw, 
	 input [2:0] adr,
    output reg [7:0] received_data, 
	 input recordData_low, recordData_high,
    inout wire sda,
    output wire scl
    );

    parameter [6:0] HARD_CODED_SLAVE_ADDR = 7'b1111111; 
	 
	 wire [7:0] slave_mem_addr;
	 reg [7:0] data;
	 assign slave_mem_addr = {5'b00000, adr};
	
	always@(*) begin
		if(recordData_low == 1)
			data[3:0] <= {rw, adr};
		if(recordData_high == 1)
			data[7:4] <= {rw, adr};
	end
	 
    parameter IDLE 				= 4'd0;
    parameter START 				= 4'd1;
    parameter ADDR 				= 4'd2;
    parameter ADDR_ACK 			= 4'd3;
	 parameter MEM_ADDR			= 4'd4;
	 parameter MEM_ADDR_ACK		= 4'd5;
    parameter WRITE 				= 4'd6;
    parameter WRITE_ACK 		= 4'd7;
    parameter READ 				= 4'd8;
    parameter READ_ACK 			= 4'd9;
    parameter STOP 				= 4'd10;

   parameter DIV_COUNT = 30'd50_000_000;

    reg [3:0] state;
    reg [2:0] bit_count = 0; 
    reg [29:0] divider = 0;
	 reg [7:0] address_and_rw=0;
    reg scl_out;
    reg sda_out;
    reg sda_oe;
	 reg ack_temp;

    wire sda_in;
    assign sda = sda_oe ? (sda_out ? 1'b1 : 1'b0) : 1'bz;
    assign scl = scl_out;
    assign sda_in = sda; 
	 reg busy = 0;
	 reg done = 0;


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;		
        end else begin
            case (state)
                IDLE: begin				 
						  sda_out <= 1;						  
						  scl_out <= 1;						  
						  sda_oe <= 1;
						  address_and_rw <= 0;
						  received_data <= 0;
						  divider <= 0;  
						  bit_count <= 0;
                    if (en) begin								
                        state <= START;
								bit_count <= 0;							
								divider <= 0;
								address_and_rw <= {HARD_CODED_SLAVE_ADDR, rw};
                        busy <= 1;
                        done <= 0;								
                    end else begin						  
								state <= IDLE;
								busy <= 0;
								done <= 0;							
								address_and_rw <= 0;								
						  end
                end

                START: begin
                    if (divider == DIV_COUNT/2) begin
                        sda_out <= 0; 								
								state <= START;								
								divider <= divider + 1;
                    end else if (divider == DIV_COUNT - 1) begin
                        scl_out <= 0; 
                        state <= ADDR;
                        divider <= 0;							
                    end else begin					  
								divider <= divider + 1;							
						      state <= START;					  
						  end
                end

                ADDR: begin
						  sda_out <= address_and_rw[7-bit_count]; 
						  if (divider == DIV_COUNT/2) begin
                        scl_out <= 1; 							
								state <= ADDR;								
								divider <= divider + 1;
                    end else if (divider == DIV_COUNT/2 + DIV_COUNT/4) begin					  
								scl_out <= 0;
								state <= ADDR;
								divider <= divider + 1;
						  end else if (divider == DIV_COUNT - 1) begin
                        if (bit_count == 7) begin
                            state <= ADDR_ACK;
                            sda_oe <= 0; 
									 bit_count <= 0;
                        end
								else begin
									bit_count <= bit_count + 1;
								end
                        divider <= 0;
                    end else begin						  
						      divider <= divider + 1;						  
						  end
                end

                ADDR_ACK: begin
                    if (divider == DIV_COUNT/2) begin
                        scl_out <= 1;
								state <= ADDR_ACK;
								divider <= divider + 1;
                    end 
						  else if (divider == DIV_COUNT/2 + DIV_COUNT/4) begin						  
								divider <= divider + 1;								
								scl_out <= 0; 
								ack_temp <= sda_in;
								state <= ADDR_ACK;
						  end 						
						  else if (divider == DIV_COUNT - 1) begin					  
								divider <= 0;																
								if (!ack_temp) begin 
                            state <= MEM_ADDR; 								 
									 sda_oe <= 1;									 
                        end else begin
                            state <= IDLE; 
                        end
                    end else begin
                        divider <= divider + 1;
                    end
                end	
					 
					 MEM_ADDR: begin
						  sda_out <= slave_mem_addr[7-bit_count]; 
						  if (divider == DIV_COUNT/2) begin 
                        scl_out <= 1; 							
								state <= MEM_ADDR;								
								divider <= divider + 1;
                    end else if (divider == DIV_COUNT/2 + DIV_COUNT/4) begin					  
								scl_out <= 0;
								state <= MEM_ADDR;
								divider <= divider + 1;
						  end else if (divider == DIV_COUNT - 1) begin
                        if (bit_count == 7) begin
                            state <= MEM_ADDR_ACK;
                            sda_oe <= 0; 
									 bit_count <= 0;
                        end
								else begin
									bit_count <= bit_count + 1;
								end
                        divider <= 0;
                    end else begin						  
						      divider <= divider + 1;						  
						  end
                end
					 
					 MEM_ADDR_ACK: begin
                    if (divider == DIV_COUNT/2) begin
                        scl_out <= 1;
								state <= MEM_ADDR_ACK;
								divider <= divider + 1;
                    end 
						  else if (divider == DIV_COUNT/2 + DIV_COUNT/4) begin						  
								divider <= divider + 1;								
								scl_out <= 0; 
								ack_temp <= sda_in;
								state <= MEM_ADDR_ACK;
						  end 						
						  else if (divider == DIV_COUNT - 1) begin					  
								divider <= 0;																
								if (!ack_temp) begin 
                            state <= address_and_rw[0] ? READ : WRITE; 								 
									 sda_oe <= address_and_rw[0] ? 0 : 1;									 
                        end else begin
                            state <= IDLE; 
                        end
                    end else begin
                        divider <= divider + 1;
                    end
                end
					 				 
					 WRITE: begin
						  sda_out <= data[7-bit_count];						
						  if (divider == DIV_COUNT/2) begin 
                        scl_out <= 1; 							
								state <= WRITE;								
								divider <= divider + 1;
                    end else if (divider == DIV_COUNT/2 + DIV_COUNT/4) begin					  
								scl_out <= 0;
								state <= WRITE;
								divider <= divider + 1;
						  end else if (divider == DIV_COUNT - 1) begin
                        if (bit_count == 7) begin
                            state <= WRITE_ACK;
                            sda_oe <= 0; 
									 bit_count <= 0;
                        end
								else begin
									bit_count <= bit_count + 1;
								end
                        divider <= 0;
                    end else begin						  
						      divider <= divider + 1;						  
						  end
                end
					 
					 WRITE_ACK: begin
						  if (divider == DIV_COUNT/2) begin
                        scl_out <= 1;
								state <= WRITE_ACK;
								divider <= divider + 1;
                    end 
						  else if (divider == DIV_COUNT/2 + DIV_COUNT/4) begin						  
								divider <= divider + 1;								
								scl_out <= 0; 
								ack_temp <= sda_in;
								state <= WRITE_ACK;
						  end 						
						  else if (divider == DIV_COUNT - 1) begin					  
								divider <= 0;																
								if (!ack_temp) begin 
                            state <= STOP; 								 
									 sda_oe <= 1;
									 sda_out <= 0;
                        end else begin
                            state <= IDLE; 
                        end
                    end else begin
                        divider <= divider + 1;
                    end
                end

               READ: begin
                   if (divider == DIV_COUNT/2) begin
                       scl_out <= 1; 
							  state <= READ;
							  divider <= divider + 1;
						 end else if (divider == DIV_COUNT/2 + DIV_COUNT/4) begin						  
								divider <= divider + 1;								
								scl_out <= 0; 
								received_data[7-bit_count] <= sda_in;
								state <= READ;
		             end else if (divider == DIV_COUNT - 1) begin
        	              if (bit_count == 7) begin 
									bit_count <= 0; 
                           state <= READ_ACK;
									sda_oe <= 1;
                       end else begin
									bit_count <= bit_count + 1;
							  end
                       divider <= 0;
                  end else begin
                       divider <= divider + 1;
                  end
                end
					 
					 READ_ACK: begin	
						 sda_out <= 0;
						 if(divider == DIV_COUNT/2)begin					
								scl_out <= 1;
								state <= READ_ACK;
								divider <= divider+1;
						 end else if (divider == DIV_COUNT/2 + DIV_COUNT/4) begin						  
								divider <= divider + 1;								
								scl_out <= 0; 
								state <= READ_ACK;
						 end else if(divider == DIV_COUNT - 1)begin
								state <= STOP;						
								divider <= 0;
						 end else begin						
								divider <= divider+1;							
						 end					 
					 end
					 
					 STOP: begin
						done <= 1;
						if (divider == DIV_COUNT/2) begin
								scl_out <= 1;
								divider <= divider + 1;
								state <= STOP;
						end else if (divider == DIV_COUNT/2 + DIV_COUNT/4) begin
								sda_out <= 1; 
								divider <= divider + 1;
								state <= STOP;
						end else if (divider == DIV_COUNT - 1) begin
								state <= IDLE;
								busy <= 0;    
						end else begin
								divider <= divider + 1;
						end
					end
					
               default: state <= IDLE; 
            endcase
        end
    end
endmodule

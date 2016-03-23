module rle (
	clk, 		
	nreset, 	
	start,
	message_addr,	
	message_size, 	
	rle_addr, 	
	rle_size, 	
	done, 		
	port_A_clk,
        port_A_data_in,
        port_A_data_out,
        port_A_addr,
        port_A_we
	);

input	clk;
input	nreset;
// Initializes the RLE module

input	start;
// Tells RLE to start compressing the given frame

input 	[31:0] message_addr;
// Starting address of the plaintext frame
// i.e., specifies from where RLE must read the plaintext frame

input	[31:0] message_size;
// Length of the plain text in bytes

input	[31:0] rle_addr;
// Starting address of the ciphertext frame
// i.e., specifies where RLE must write the ciphertext frame

input   [31:0] port_A_data_out;
// read data from the dpsram (plaintext)

output  [31:0] port_A_data_in;
// write data to the dpsram (ciphertext)

output  [15:0] port_A_addr;
// address of dpsram being read/written

output  port_A_clk;
// clock to dpsram (drive this with the input clk)

output  port_A_we;
// read/write selector for dpsram

output	[31:0] rle_size;
// Length of the compressed text in bytes

output	done; // done is a signal to indicate that encryption of the frame is complete

reg [15:0] incr_rle; // reg to increment rle address
reg [15:0] incr_mess; // reg to increment message address
reg [31:0] port_A_data_in;
reg [15:0] port_A_addr=0;
reg port_A_we;
reg [15:0] size; // size of plain text

reg [3:0] state;
reg [3:0] prev_state; // reg to keep track of previous state to know which state to go to after write
reg [15:0] counter; // counter to keep track of how many letter there are
reg counter_write; // counter for writing to DPSRAM

reg [7:0] word;
reg [31:0] word_out;
/* 
reg [7:0] word1;
reg [7:0] word2;
reg [7:0] word3;
reg [7:0] word4; 
*/

reg [31:0] rle_size; // 
reg done;

assign port_A_clk = clk; // drive dpsram clock with input clock 

parameter IDLE=4'b1111;
parameter s0=4'b0000, s1=4'b0001, s2=4'b0010, s3=4'b0011, s4=4'b0100, s5=4'b0101;
parameter WRITE_1=4'b0110, WRITE_2=4'b0111, buffer=4'b1000;


always @(posedge clk or negedge nreset)		// always block for updating state register
begin
	if (!nreset) begin		
		state <= IDLE;
		counter <= 16'b1;
		counter_write <= 0;
		done <= 0;
	end else begin 
		case(state)
		
			IDLE: begin // IDLE state. If start = 1 then transfer data to corresponding reg
				if(start) begin
					incr_mess <= 16'b0;
					incr_rle <= 16'b0;
					rle_size <= 32'b0;
					counter <= 16'b1;
					counter_write <= 1'b0;
					size <= message_size + 4;
					prev_state <= IDLE;
					port_A_addr<=message_addr;
					state <= s0;
					done <= 0;
					port_A_we <= 0;
				end
			end
			
			s0: begin
				if(size < 4) begin
			
					if(rle_size%4 == 2)begin
						port_A_addr <= (rle_addr + incr_rle);
						port_A_data_in[31:24] <= 0;
						port_A_data_in[23:16] <= 0;
						port_A_we<=1;
					end
				
					state <= IDLE;
					done <= 1;
					
	
				end else begin
					port_A_addr <= (message_addr + incr_mess);
					port_A_we <= 0;
					state <= buffer;				
										
				end
			end	
			
			buffer: begin
				state <= s1;
				end
				
			s1: begin
				size <= (size - 4);
				word_out <= port_A_data_out;
				/*
				word1 <= port_A_data_out[7:0];
				word2 <= port_A_data_out[15:8];
				word3 <= port_A_data_out[23:16];
				word4 <= port_A_data_out[31:24];
				*/
				
				if(prev_state == s4 || prev_state == WRITE_2)
					state <= s5;
				else
					state <= s2;
			end
				
			s2: begin
				port_A_we <= 0;
				if(word_out[7:0]==word_out[15:8] && word_out[15:8]==word_out[23:16] && word_out[23:16]==word_out[31:24]) begin
					counter <= counter + 3;
					prev_state <= s4;
					word <= word_out[31:24];
					incr_mess<= (incr_mess + 4);
					state <= s0;
				end else if(word_out[7:0] == word_out[15:8]) begin
					counter <= counter + 1;
					state <= s3;
				end else begin
					word <= word_out[7:0];
					prev_state <= s2;
					state <= WRITE_1;
				end
			end	
				
			s3: begin
				port_A_we <= 0;
				if(word_out[15:8] == word_out[23:16]) begin
					counter <= counter + 1;
					state <= s4;
				end else begin
					word <= word_out[15:8];
					prev_state <= s3;
					state <= WRITE_1;
				end
			end	
				
			s4: begin
				port_A_we <= 0;	
				if(word_out[23:16] == word_out[31:24]) begin
					counter <= counter + 1;
					prev_state <= s4;
					word <= word_out[31:24];
					incr_mess<= (incr_mess+4);
					state <= s0;
				end else begin
					word <= word_out[23:16];
					prev_state <= s4;
					state <= WRITE_1;
				end
			end
				
			s5: begin
				port_A_we <= 0;	
				if(word == word_out[7:0]) begin
					counter <= counter + 1;
					state <= s2;
				end else begin
					prev_state <= s5;
					state <= WRITE_1;
				end
			end
				
			WRITE_1: begin
				if(counter_write == 1) begin
					port_A_data_in[31:24] <= word;
					port_A_data_in[23:16] <= counter;
					rle_size<=rle_size+2;
				end else begin
					port_A_data_in[15:8] <= word;
					port_A_data_in[7:0] <= counter;
					rle_size <= rle_size + 2;
				end
				state <= WRITE_2;
			end
				
			WRITE_2: begin
				if(counter_write == 1) begin
					port_A_addr <= (rle_addr + incr_rle);
					port_A_we <= 1;
					counter_write <= 1'b0;
					counter <= 16'b1;
					incr_rle <= (incr_rle + 4);
				
					if(prev_state == s2) 
						state <= s3;
					else if(prev_state == s3)
						state <= s4;
					else if(prev_state == s4) begin
						incr_mess <= (incr_mess + 4);
						word <= word_out[31:24];
						state <= s0;
					end else if(prev_state == s5)begin
						state <= s2;
					end
				end else begin
					counter_write <= 1'b1;
					counter <= 16'b1;
					prev_state <= WRITE_2;
				
					if(prev_state == s2) 
						state <= s3;
					else if(prev_state == s3) 
						state <= s4;
					else if(prev_state == s4) begin
						incr_mess <= (incr_mess + 4);
						word <= word_out[31:24];
						state <= s0;
					end else if(prev_state == s5)begin
						state <= s2;	
					end
				end
			end
			
			default: begin
				state <= IDLE;
			end
			
			endcase
	end
end
endmodule 















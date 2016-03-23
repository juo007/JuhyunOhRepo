module SHA1_hash (       
	clk, 		
	nreset, 	
	start_hash,  
	message_addr,	
	message_size, 	
	hash, 	
	done, 		
	port_A_clk,
        port_A_data_in,
        port_A_data_out,
        port_A_addr,
        port_A_we
	);

input	clk;
input	nreset; 
// Initializes the SHA1_hash module

input	start_hash; 
// Tells SHA1_hash to start hashing the given frame

input 	[31:0] message_addr; 
// Starting address of the messagetext frame
// i.e., specifies from where SHA1_hash must read the messagetext frame

input	[31:0] message_size; 
// Length of the message in bytes

output	[159:0] hash; 
// hash results

input   [31:0] port_A_data_out; 
// read data from the dpsram (messagetext)

output  [31:0] port_A_data_in;
// write data to the dpsram (ciphertext)

output  [15:0] port_A_addr;
// address of dpsram being read/written 

output  port_A_clk;
// clock to dpsram (drive this with the input clk) 

output  port_A_we; // read/write selector for dpsram
integer i; // for loop for padding


output	done; // done is a signal to indicate that hash  is complete

assign port_A_clk = clk; // drive dpsram clock with input clock


function [31:0] changeEndian;   //transform data from the memory to big-endian form
    input [31:0] value;
    changeEndian = {value[7:0], value[15:8], value[23:16], value[31:24]};
endfunction

function [31:0] f1;
	input [31:0] x, y, z;
	f1 = {(x & y) ^ (~x & z)};
endfunction

function [31:0] f2;
	input [31:0] x, y, z;
	f2 = {x ^ y ^ z};
endfunction

function [31:0] f3;
	input [31:0] x, y, z;
	f3 = {(x & y) ^ (x & z) ^ (y & z)};
endfunction

function [31:0] T;
	input [31:0] a, b, c, d;	
	T = {a[30:0],a[31]} ^ {b[30:0],b[31]} ^ {c[30:0],c[31]} ^ {d[30:0],d[31]};
endfunction



reg done;
reg [31:0] port_A_data_in;
reg [15:0] port_A_addr = 0;
reg [159:0] hash ;
reg port_A_we;

reg [10:0] addr;

reg [7:0] incr_mess; // register to increment message address
reg [8:0] size; // message size
reg [3:0] state; // 4-bit register to hold state 

reg [31:0] A = 32'h67452301;
reg [31:0] B = 32'hEFCDAB89;
reg [31:0] C = 32'h98BADCFE; 
reg [31:0] D = 32'h10325476;
reg [31:0] E = 32'hC3D2E1F0;


reg [31:0] w[0:15]; // shift word registers
reg [7:0] count;
reg [1:0] padflag=2'b00;

wire [31:0] x1,x2,x3,x4;

assign x1 = w[15] + 32'h5a827999;
assign x2 = w[15] + 32'h6ed9eba1;
assign x3 = w[15] + 32'h8f1bbcdc;
assign x4 = w[15] + 32'hca62c1d6;




parameter IDLE=4'b0000, read=4'b0001, buffer=4'b0010, r1=4'b0011;
parameter c1=4'b0100, d1=4'b0101, pad0=4'b0111,pad1=4'b1000;
always @(posedge clk or negedge nreset)
begin
	if(!nreset) begin
	
		state <= IDLE;
		count <= 0;
		done <= 0;
		
		
	end else begin
		case(state)
		
			IDLE: begin
				if(start_hash) begin // initialize starting values
					incr_mess <= 16'b0;
					addr <= message_addr;
					port_A_we <= 0;
					size <= message_size;
					done <= 0;
					count <= 0;
					padflag = 2'b00;
					hash[159:128] <= 32'h67452301;
					hash[127:96] <= 32'hEFCDAB89;
					hash[95:64] <= 32'h98BADCFE;
					hash[63:32] <= 32'h10325476;
					hash[31:0] <= 32'hC3D2E1F0;
					state <= read;
				end
			end

			read: begin
				if (size == 0)begin
					done<=1;
				end	
				else begin	//start of processing the 512-bit BLOCk
					port_A_addr <= addr + (incr_mess);
					port_A_we <= 0;
					incr_mess <= incr_mess + 4;
					count<=0;
					//A <= hash[159:128];
					//B <= hash[127:96];
					//C <= hash[95:64];
					//D <= hash[63:32];
					//E <= hash[31:0];
					state <= buffer;
				end
			end

			buffer: begin
				state <= r1;
			end
			
			r1:begin		
				
				w[count] <= changeEndian(port_A_data_out);
										
				if(count!=15 && ((size>>2) != count))begin
					port_A_addr <= addr + incr_mess;
					incr_mess <= incr_mess + 4;
				end
				
				if((size>>2) == count)begin
					state <= pad0;
				end else
					state <= c1;				
				
			end			
			
		c1:begin
				
				if (count < 16)
					A <= {A[26:0], A[31:27]} + w[count] + f1(B,C,D) + 32'h5a827999 + E; 
				else if (count < 20)
					A <= {A[26:0], A[31:27]} + x1 + f1(B,C,D) + E;
				else if (count < 40)
					A <= {A[26:0], A[31:27]} + x2 + f2(B,C,D) + E; 
				else if (count < 60)
					A <= {A[26:0], A[31:27]} + x3 + f3(B,C,D) + E; 
				else 
					A <= {A[26:0], A[31:27]} + x4 + f2(B,C,D) + E; 
								
				B <= A;
				C <= {B[1:0], B[31:2]};
				D <= C;
				E <= D;								
				
				if(count < 15 && padflag==2'b00)begin
					count <= count + 1;
					state <= r1;
				end else if (count < 15 && padflag!=2'b00)begin
					count <= count + 1;
					state <= c1;
				end else if(count==79)begin
					state <= d1;				
				end else begin
					
					count <= count + 1;
					state <= c1;
					
					w[15] <= T(w[13],w[8],w[2],w[0]);
					w[14] <= w[15];
					w[13] <= w[14];
					w[12] <= w[13];
					w[11] <= w[12];
					w[10] <= w[11];
					w[9] <= w[10];
					w[8] <= w[9];
					w[7] <= w[8];
					w[6] <= w[7];
					w[5] <= w[6];
					w[4] <= w[5];
					w[3] <= w[4];
					w[2] <= w[3];
					w[1] <= w[2];
					w[0] <= w[1];

					//w[count[3:0]+4'b0001] <= T(w[count[3:0]+4'b1110],w[count[3:0]+4'b1001],w[count[3:0]+4'b0011],w[count[3:0]+4'b0001]);	
				end
				
			end
			
			d1:begin
			
				//A <= hash[159:128] + A;
				//B <= hash[127:96] + B;
				//C <= hash[95:64] + C;
				//D <= hash[63:32] + D;
				//E <= hash[31:0] + E;
				
				if(padflag == 2'b00)begin
					size <= size - 64;
					state <= read;
					A <= hash[159:128] + A;
					B <= hash[127:96] + B;
					C <= hash[95:64] + C;
					D <= hash[63:32] + D;
					E <= hash[31:0] + E;
				end else if (padflag == 2'b10)begin
					state <= pad1;	
					A <= hash[159:128] + A;
					B <= hash[127:96] + B;
					C <= hash[95:64] + C;
					D <= hash[63:32] + D;
					E <= hash[31:0] + E;
				end else begin
					done <=1;
					hash[159:128] <= hash[159:128] + A;
					hash[127:96] <= hash[127:96] + B;
					hash[95:64] <= hash[95:64] + C;
					hash[63:32] <= hash[63:32] + D;
					hash[31:0] <= hash[31:0] + E;
				end
				
			end
			pad0: begin
				if(size%4==1)begin
					w[count] <= {w[count][31:24] , 24'h800000};
				end else if (size%4==2)begin
					w[count] <= {w[count][31:16] , 16'h8000};
				end else if (size%4==3)
					w[count] <= {w[count][31:8] , 8'h80};
				else
					w[count] <= 32'h80000000;
				
				for(i=1;i<14;i=i+1)begin
					if(count+i != 14) 
						w[count+i] <= 32'h00000000;
				end			
				
				if(count < 14)begin
					w[14] <= 32'h00000000;
					w[15] <= message_size << 3;
				end else	if(count == 14) 
					w[15] <= 32'h00000000;					
				
				if(size > 55)
					padflag <= 2'b10;
				else
					padflag <= 2'b01;
					
				state<=c1;			
			end	
			pad1: begin
				w[0] <= 32'h00000000;	
				w[1] <= 32'h00000000;
				w[2] <= 32'h00000000;
				w[3] <= 32'h00000000;
				w[4] <= 32'h00000000;
				w[5] <= 32'h00000000;
				w[6] <= 32'h00000000;
				w[7] <= 32'h00000000;
				w[8] <= 32'h00000000;
				w[9] <= 32'h00000000;
				w[10] <= 32'h00000000;
				w[11] <= 32'h00000000;
				w[12] <= 32'h00000000;
				w[13] <= 32'h00000000;
				w[14] <= 32'h00000000;
				w[15] <= message_size << 3; 
				//A <= hash[159:128]; 
				//B <= hash[127:96]; 
				//C <= hash[95:64]; 
				//D <= hash[63:32];
				//E <= hash[31:0];
				count<=0;
				state <= c1;
				padflag <= 2'b11;
			end			

			endcase
		end
	end
endmodule 

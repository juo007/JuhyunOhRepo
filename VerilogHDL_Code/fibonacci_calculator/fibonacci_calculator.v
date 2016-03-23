module fibonacci_calculator(
clk,
reset_n,
input_s,
begin_fibo,
done,
fibo_out
);

input [4:0] input_s;
input reset_n;
input begin_fibo;
input clk;
output done;
output[15:0] fibo_out;

reg state;
reg [4:0] signal;
reg [15:0] fibo_out;
reg done;
reg [15:0] f0;
reg [15:0] f1;
reg [4:0] counter;

parameter s0=0,s1=1;			

always @ (posedge clk or negedge reset_n)
	begin
		if(!reset_n)begin
			state<=s0;
			f0<=16'b0;
			f1<=16'b1;
			counter<=4'b1;
			fibo_out<=16'b0;
			done<=0;
			signal<=4'b0;
			end			
		else begin
			case(state)
				s0:begin							//Idle state
					done<=0;
					if(begin_fibo)begin
						state<=s1;
						signal<=input_s;
						end
					else 
						state<=s0;
					end
				s1:begin
					if(signal==0)begin
						fibo_out<=16'b0;
						done<=1;
						state<=s0;
						end
					else if(signal==1)begin
						fibo_out<=16'b1;
						done<=1;
						state<=s0;
						end
					else begin
						f0<=f1;
						f1<=f0+f1;
						counter<=counter+1;
						if(counter+1==signal)begin	
							done<=1;
							fibo_out<=f1+f0;
							state<=s0;
							end	
						end						
					end
				endcase
			end
			
	end

endmodule

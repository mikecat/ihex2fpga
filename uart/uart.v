module uart_rx(clock, reset, prescaler_max, we_out, data_out, signal_in);
	input clock;
	input reset;
	input [15:0] prescaler_max;
	output we_out;
	output [7:0] data_out;
	input signal_in;

	reg [15:0] prescaler;
	reg [7:0] data;
	reg [1:0] phase;
	reg [2:0] data_bit;
	reg frame_error;

	reg we_out;
	reg [7:0] data_out;

	always @(posedge clock) begin
		if (reset) begin
			prescaler <= 15'd0;
			data <= 8'd0;
			phase <= 2'd0;
			data_bit <= 3'd0;
			frame_error <= 1'b0;
			we_out <= 1'b0;
			data_out <= 8'd0;
		end else begin
			if (phase == 2'd0) begin
				if (~signal_in) begin
					prescaler <= {1'b0, prescaler_max[15:1]} + 16'd1;
					phase <= 2'd1;
				end
			end else if (frame_error) begin
				if (signal_in) begin
					phase <= 2'd0;
					frame_error <= 1'b0;
				end
			end else begin
				if (prescaler == prescaler_max) begin
					if (phase == 2'd1) begin // スタートビット
						if (~signal_in) begin
							data_bit <= 3'd0;
							phase <= 2'd2;
						end else begin
							phase <= 2'd0;
						end
					end else if (phase == 2'd2) begin // データ (8ビット)
						data <= {signal_in, data[7:1]};
						if (data_bit == 3'd7) begin
							phase <= 2'd3;
						end else begin
							data_bit <= data_bit + 3'd1;
						end
					end else if (phase == 2'd3) begin // ストップビット
						if (signal_in) begin
							we_out <= 1'b1;
							data_out <= data;
							phase <= 2'd0;
						end else begin
							frame_error <= 1'b1;
						end
					end
					prescaler <= 16'd0;
				end else begin
					prescaler <= prescaler + 16'd1;
				end
			end
			if (we_out) begin
				we_out <= 1'b0;
			end
		end
	end

endmodule

module uart_tx(clock, reset, prescaler_max, sendable, sendreq, data_in, signal_out);
	input clock;
	input reset;
	input [15:0] prescaler_max;
	output sendable;
	input sendreq;
	input [7:0] data_in;
	output signal_out;

	reg [15:0] prescaler;
	reg [7:0] data;
	reg [1:0] phase;
	reg [2:0] data_bit;

	wire next = prescaler == prescaler_max;
	wire sendable = phase == 2'd0 || (next && phase == 2'd3);
	reg signal_out;

	always @(posedge clock) begin
		if (reset) begin
			prescaler <= 15'd0;
			data <= 8'd0;
			phase <= 2'd0;
			data_bit <= 3'd0;
			signal_out <= 1'b1;
		end else begin
			if (phase == 2'd0) begin
				if (sendreq) begin
					phase <= 2'd1;
					data <= data_in;
					signal_out <= 1'b0;
				end
			end else begin
				if (next) begin
					if (phase == 2'd1) begin // スタートビット
						signal_out <= data[0];
						data <= {1'b0, data[7:1]};
						phase <= 2'd2;
						data_bit <= 3'd0;
					end else if (phase == 2'd2) begin // データ (8ビット)
						if (data_bit == 3'd7) begin
							signal_out <= 1'd1;
							phase <= 2'd3;
						end else begin
							signal_out <= data[0];
							data <= {1'b0, data[7:1]};
							data_bit <= data_bit + 3'd1;
						end
					end else if (phase == 2'd3) begin // ストップビット
						if (sendreq) begin
							phase <= 2'd1;
							data <= data_in;
							signal_out <= 1'b0;
						end else begin
							phase <= 2'd0;
							signal_out <= 1'b1;
						end
					end
					prescaler <= 16'd0;
				end else begin
					prescaler <= prescaler + 16'd1;
				end
			end
		end
	end

endmodule

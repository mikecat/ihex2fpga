`timescale 1ns/1ns

module uart_test;
	reg clock;
	reg reset;
	reg [7:0] data[255:0];
	reg [5:0] wait_cnt;
	integer i;

	wire [15:0] prescaler_max = 16'd3;

	reg [7:0] tx_pos;
	reg tx_req;
	reg [7:0] tx_data;

	wire uart_signal;
	wire we_rx;
	wire [7:0] data_rx;

	initial begin
		$dumpfile("result.vcd");
		$dumpvars(0, uart_test);
		for (i = 0; i < 256; i = i + 1) begin
			data[i] = 8'd0;
		end
		data[0] = 8'h55;
		data[1] = 8'haa;
		data[3] = 8'h25;
		clock <= 1'b0;
		reset <= 1'b1;
		wait_cnt <= 6'd10;
		tx_pos <= 8'd0;
		tx_req <= 1'b0;
		tx_data <= 8'd0;
	end
	always #50 begin
		clock <= ~clock;
	end
	initial #100 begin
		reset <= 1'b0;
	end
	initial #40000 begin
		$finish;
	end

	always @(posedge clock) begin
		if (wait_cnt == 6'd0) begin
			if (data[tx_pos] == 8'd0) begin
				tx_req <= 1'b0;
				wait_cnt <= 6'd45;
				tx_pos <= tx_pos + 8'd1;
			end else begin
				tx_req <= 1'b1;
				tx_data <= data[tx_pos];
				if (tx_req && sendable) begin
					tx_pos <= tx_pos + 8'd1;
				end
			end
		end else begin
			wait_cnt <= wait_cnt - 6'd1;
		end
	end

	uart_tx tx(
		.clock(clock), .reset(reset), .prescaler_max(prescaler_max),
		.sendable(sendable), .sendreq(tx_req), .data_in(tx_data), .signal_out(uart_signal)
	);
	uart_rx rx(
		.clock(clock), .reset(reset), .prescaler_max(prescaler_max),
		.we_out(we_rx), .data_out(data_rx), .signal_in(uart_signal)
	);

endmodule

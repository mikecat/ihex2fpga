`timescale 1ns/1ns

module ihex_uart_test;
	reg clock;
	reg reset;
	reg sendreq;
	reg [7:0] file_data;
	integer fd;

	wire [15:0] prescaler = 16'd3;
	wire sendable;
	wire we_out;
	wire [7:0] data_out;

	initial begin
		$dumpfile("result.vcd");
		$dumpvars(0, ihex_uart_test);
		fd = $fopen("ihex/test.hex", "r");
		if (fd == 0) begin
			$display("fopen failed");
			$finish;
		end
		file_data = $fgetc(fd);
		sendreq <= 1'b1;
		clock <= 1'b0;
		reset <= 1'b1;
	end
	always #50 begin
		clock <= ~clock;
	end
	initial #100 begin
		reset <= 1'b0;
	end
	initial #10000000 begin
		$fclose(fd);
		$finish;
	end

	ihex_uart ihex_uart(
		.clock(clock), .reset(reset),
		.prescaler(prescaler), .rx(rx), .tx(tx)
	);
	uart_tx uart_tx(
		.clock(clock), .reset(reset), .prescaler_max(prescaler),
		.sendable(sendable), .sendreq(sendreq), .data_in(file_data), .signal_out(rx)
	);
	uart_rx uart_rx(
		.clock(clock), .reset(reset), .prescaler_max(prescaler),
		.we_out(we_out), .data_out(data_out), .signal_in(tx)
	);

	always @(posedge clock) begin
		if (~reset) begin
			if (sendreq & sendable) begin
				if ($feof(fd) == 0) begin
					file_data <= $fgetc(fd);
					sendreq <= 1'b1;
				end else begin
					sendreq <= 1'b0;
				end
			end
			if (we_out) begin
				// TODO: data_outの一部だけ不定の場合の処理
				if (data_out === 8'bxxxxxxxx) begin
					$write("?");
				end else begin
					$write("%c", data_out);
				end
			end
		end
	end

endmodule

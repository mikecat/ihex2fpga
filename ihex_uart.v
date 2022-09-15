module ihex_uart(clock, reset, prescaler, rx, tx);
	input clock;
	input reset;
	input [15:0] prescaler;
	input rx;
	output tx;

	reg [7:0] data[255:0];

	reg [7:0] tx_address;
	reg [1:0] tx_phase;
	reg tx_running;

	wire [7:0] tx_byte = data[tx_address];
	wire [7:0] hex_upper = (tx_byte[7:4] < 4'ha ? 8'h30 : 8'h57) + {4'd0, tx_byte[7:4]};
	wire [7:0] hex_lower = (tx_byte[3:0] < 4'ha ? 8'h30 : 8'h57) + {4'd0, tx_byte[3:0]};

	wire [7:0] data_tx =
		tx_phase == 2'd0 ? hex_upper :
		tx_phase == 2'd1 ? hex_lower :
		tx_address[3:0] == 4'hf ? 8'h0a : 8'h20;

	wire we_rx;
	wire [7:0] data_rx;
	wire sendable;
	wire data_write_enable;
	wire [7:0] data_to_write;
	wire [31:0] write_address;
	wire [31:0] start_address;
	wire end_of_file;
	wire line_error;

	uart_rx rx_module(
		.clock(clock), .reset(reset), .prescaler_max(prescaler),
		.we_out(we_rx), .data_out(data_rx), .signal_in(rx)
	);

	uart_tx tx_module(
		.clock(clock), .reset(reset), .prescaler_max(prescaler),
		.sendable(sendable), .sendreq(tx_running), .data_in(data_tx), .signal_out(tx)
	);

	ihex_decoder ihex(
		.clock(clock), .reset(reset),
		.we_in(we_rx), .data_in(data_rx), .write_done(1'b1),
		.we_out(data_write_enable), .data_out(data_to_write),
		.address_out(write_address), .start_address(start_address),
		.end_of_file(end_of_file), .line_error(line_error)
	);

	always @(posedge clock) begin
		if (reset) begin
			tx_address <= 8'd0;
			tx_phase <= 2'd0;
		end else begin
			if (data_write_enable) begin
				data[write_address[7:0]] <= data_to_write;
			end
			if (end_of_file) begin
				tx_address <= 8'd0;
				tx_phase <= 2'd0;
				tx_running <= 1'b1;
			end
			if (tx_running) begin
				if (sendable) begin
					if (tx_phase == 2'd2) begin
						if (tx_address == 8'hff) begin
							tx_address <= 8'd0;
							tx_running <= 1'b0;
						end else begin
							tx_address <= tx_address + 8'd1;
						end
						tx_phase <= 2'd0;
					end else begin
						tx_phase <= tx_phase + 2'd1;
					end
				end
			end
		end
	end

endmodule

`timescale 1ns/1ns

module ihex_decoder_test;
	reg clock;
	reg reset;
	reg [3:0] prescaler;
	reg we;
	reg [7:0] file_data;
	reg end_flag;
	integer fd;

	wire we_out;
	wire [7:0] data_out;
	wire [31:0] address_out;
	wire [31:0] start_address;
	wire end_of_file;
	wire line_error;

	initial begin
		$dumpfile("result.vcd");
		$dumpvars(0, ihex_decoder_test);
		fd = $fopen("test.hex", "r");
		if (fd == 0) begin
			$display("fopen failed");
			$finish;
		end
		clock <= 1'b0;
		reset <= 1'b1;
		prescaler <= 4'd0;
		we <= 1'd0;
		end_flag <= 1'd0;
	end
	always #50 begin
		clock <= ~clock;
	end
	initial #100 begin
		reset <= 1'b0;
	end
	always @(posedge clock) begin
		if (~reset) begin
			prescaler <= prescaler + 4'd1;
			if (prescaler == 4'hf) begin
				if ($feof(fd) == 0) begin
					file_data <= $fgetc(fd);
					we <= 1'b1;
				end
				if (end_flag) begin
					$fclose(fd);
					$finish;
				end
			end else begin
				we <= 1'b0;
			end
			if(end_of_file) end_flag <= 1'b1;
			if (we_out) begin
				$display("%08x: %02x", address_out, data_out);
			end
		end
	end

	ihex_decoder decoder(
		.clock(clock), .reset(reset),
		.we_in(we), .data_in(file_data), .write_done(1'b1),
		.we_out(we_out), .data_out(data_out), .address_out(address_out), .start_address(start_address),
		.end_of_file(end_of_file), .line_error(line_error)
	);

	initial #1000000 begin
		$fclose(fd);
		$finish;
	end
endmodule

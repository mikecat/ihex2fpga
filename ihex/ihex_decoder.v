module ihex_decoder(
	clock, reset,
	we_in, data_in, write_done,
	we_out, data_out, address_out, start_address,
	end_of_file, line_error
);
	input clock;
	input reset;
	input we_in;
	input [7:0] data_in;
	input write_done;
	output we_out;
	output [7:0] data_out;
	output [31:0] address_out;
	output [31:0] start_address;
	output end_of_file;
	output line_error;

	reg colon_seen;
	reg line_error_flag;
	reg [3:0] first_nibble;
	reg first_nibble_read;
	reg [1:0] read_phase;
	reg [7:0] data_size_field;
	reg [15:0] address_field;
	reg read_address_high;
	reg [7:0] type_field;
	reg [7:0] last_byte;
	reg last_byte_valid;
	reg [7:0] checksum_computed;

	reg [7:0] data_field[255:0];
	reg [7:0] data_field_read_size;
	reg [31:0] data_field_first;
	reg [31:0] address_offset;

	reg [7:0] writing_pos;
	reg [7:0] writing_size;
	reg [31:0] writing_offset;
	reg writing;

	wire we_out = writing;
	wire [7:0] data_out = data_field[writing_pos];
	wire [31:0] address_out = writing_offset + {24'd0, writing_pos};

	reg [31:0] start_address;
	reg end_of_file;
	reg line_error;

	wire is_colon = data_in == 8'h3a;
	wire is_newline = data_in == 8'h0d || data_in == 8'h0a;
	wire is_number = 8'h30 <= data_in && data_in <= 8'h39;
	wire is_upper = 8'h41 <= data_in && data_in <= 8'h46;
	wire is_lower = 8'h61 <= data_in && data_in <= 8'h66;
	wire is_xdigit = is_number | is_upper | is_lower;
	wire [3:0] xdigit =
		is_number ? data_in[3:0] :
		is_upper | is_lower ? data_in[3:0] + 4'd9 :
		4'd0;
	wire [7:0] byte_read = {first_nibble, xdigit};

	always @(posedge clock) begin
		if (reset) begin
			colon_seen <= 1'b0;
			line_error_flag <= 1'b0;
			first_nibble <= 4'd0;
			first_nibble_read <= 1'b0;
			read_phase <= 2'b0;
			data_size_field <= 8'd0;
			address_field <= 16'd0;
			read_address_high <= 1'b0;
			type_field <= 8'd0;
			last_byte <= 8'd0;
			last_byte_valid <= 1'b0;
			data_field_read_size <= 8'd0;
			data_field_first <= 32'd0;
			address_offset <= 32'd0;
			writing_pos <= 8'd0;
			writing_size <= 8'd0;
			writing <= 1'b0;
			start_address <= 32'd0;
			end_of_file <= 1'b0;
			line_error <= 1'b0;
		end else begin
			if (we_in) begin
				if (colon_seen) begin
					if (is_xdigit) begin
						if (first_nibble_read) begin
							first_nibble_read <= 1'b0;
							if (last_byte_valid) begin
								case (read_phase)
									2'd0: begin
										data_size_field <= last_byte;
										read_phase <= 2'd1;
										read_address_high <= 1'b1;
									end 2'd1: begin
										if (read_address_high) begin
											address_field <= {last_byte, address_field[7:0]};
											read_address_high <= 1'b0;
										end else begin
											address_field <= {address_field[15:8], last_byte};
											read_phase <= 2'd2;
										end
									end 2'd2: begin
										type_field <= last_byte;
										read_phase <= 2'd3;
										data_field_read_size <= 8'd0;
										data_field_first <= 32'd0;
									end 2'd3: begin
										case (data_field_read_size)
											8'd0: data_field_first <= {last_byte, data_field_first[23:0]};
											8'd1: data_field_first <= {data_field_first[31:24], last_byte, data_field_first[15:0]};
											8'd2: data_field_first <= {data_field_first[31:16], last_byte, data_field_first[7:0]};
											8'd3: data_field_first <= {data_field_first[31:8], last_byte};
										endcase
										if (data_field_read_size < 8'hff) begin
											data_field[data_field_read_size] <= last_byte;
											data_field_read_size <= data_field_read_size + 8'd1;
										end else begin
											line_error_flag <= 1'b1;
										end
									end
								endcase
							end
							checksum_computed <= checksum_computed + byte_read;
							last_byte <= byte_read;
							last_byte_valid <= 1'b1;
						end else begin
							first_nibble <= xdigit;
							first_nibble_read <= 1'b1;
						end
					end else if (is_newline) begin
						if (line_error_flag || read_phase != 2'd3 || data_field_read_size != data_size_field || checksum_computed != 8'd0) begin
							line_error <= 1'b1;
						end else begin
							case (type_field)
								8'h00: begin // データ
									if (data_size_field > 8'd0) begin
										writing_pos <= 8'd0;
										writing_size <= data_size_field;
										writing_offset <= address_offset + {16'd0, address_field};
										writing <= 1'b1;
									end
								end 8'h01: begin // End of File
									if (data_size_field == 8'd0) begin
										end_of_file <= 1'b1;
										address_offset <= 32'd0;
									end else begin
										line_error <= 1'b1;
									end
								end 8'h02: begin // 拡張セグメントアドレス
									if (data_size_field == 8'd2) begin
										address_offset <= {12'd0, data_field_first[31:16], 4'd0};
									end else begin
										line_error <= 1'b1;
									end
								end 8'h03: begin // 開始セグメントアドレス
									if (data_size_field == 8'd4) begin
										start_address <= {12'd0, data_field_first[31:16], 4'd0} + {16'd0, data_field_first[15:0]};
									end else begin
										line_error <= 1'b1;
									end
								end 8'h04: begin // 拡張リニアアドレス
									if (data_size_field == 8'd2) begin
										address_offset <= {data_field_first[31:16], 16'd0};
									end else begin
										line_error <= 1'b1;
									end
								end 8'h05: begin // 開始リニアアドレス
									if (data_size_field == 8'd4) begin
										start_address <= data_field_first;
									end else begin
										line_error <= 1'b1;
									end
								end default: begin
									line_error <= 1'b1;
								end
							endcase
						end
						colon_seen <= 1'b0;
					end else begin
						line_error_flag <= 1'b1;
					end
				end else begin
					if (is_colon) begin
						colon_seen <= 1'b1;
						line_error_flag <= 1'b0;
						read_phase <= 2'b0;
						last_byte_valid <= 1'b0;
						first_nibble_read <= 1'b0;
						checksum_computed <= 8'd0;
					end
				end
			end
			if (end_of_file) begin
				end_of_file <= 1'b0;
				start_address <= 32'd0;
			end
			if (line_error) line_error <= 1'b0;
			if (writing) begin
				if (write_done) begin
					if (writing_pos + 8'd1 < writing_size) begin
						writing_pos <= writing_pos + 8'd1;
					end else begin
						writing <= 1'b0;
					end
				end
			end
		end
	end

endmodule

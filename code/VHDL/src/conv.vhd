library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
	use ieee.fixed_pkg.all;
	use ieee.fixed_float_types.all;
library util;
	use util.math.all;

-----------------------------------------------------------------------------------------------------------------------
-- Entity Section
-----------------------------------------------------------------------------------------------------------------------
entity conv is
	generic (
		C_DATA_WIDTH_DATA		: integer range 1 to 16 := 8;
		C_FRAC_WIDTH_IN			: integer range 0 to 16 := 4;
		C_DATA_WIDTH_WEIGHTS 	: integer range 1 to 16 := 8;
		C_FRAC_WIDTH_WEIGHTS	: integer range 0 to 16 := 4;
		C_CONV_DIM 				: integer range 1 to 3 := 3
	);
	port ( 
		isl_clk 		: in std_logic;
		isl_rst_n		: in std_logic;
		isl_ce			: in std_logic;
		isl_valid		: in std_logic;
		islv_data		: in std_logic_vector(C_CONV_DIM*C_CONV_DIM*C_DATA_WIDTH_DATA-1 downto 0);
		islv_weights	: in std_logic_vector(C_CONV_DIM*C_CONV_DIM*C_DATA_WIDTH_WEIGHTS-1 downto 0);
		oslv_data		: out std_logic_vector(C_DATA_WIDTH_DATA+C_DATA_WIDTH_WEIGHTS+log2(C_CONV_DIM-1)*2 downto 0);
		osl_valid		: out std_logic
    );
end conv;

-----------------------------------------------------------------------------------------------------------------------
-- Architecture Section
-----------------------------------------------------------------------------------------------------------------------
architecture behavioral of conv is

	------------------------------------------
	-- Signal Declarations
	------------------------------------------
	signal slv_stage				: std_logic_vector(2 to 6) := (others => '0');
	
	type t_1d_sfix_array is array (natural range <>) of sfixed(C_DATA_WIDTH_DATA-C_FRAC_WIDTH_IN-1 downto -C_FRAC_WIDTH_IN);
	signal a_sfix_data 				: t_1d_sfix_array(0 to C_CONV_DIM*C_CONV_DIM-1);
	
	-- full signal bitwidth after multiplication
	type t_1d_sfix_mult_array is array (natural range <>) of sfixed(C_DATA_WIDTH_DATA-C_FRAC_WIDTH_IN+C_DATA_WIDTH_WEIGHTS-C_FRAC_WIDTH_WEIGHTS-1 downto -C_FRAC_WIDTH_IN-C_FRAC_WIDTH_WEIGHTS);
	signal a_data_mult 					: t_1d_sfix_mult_array(0 to C_CONV_DIM*C_CONV_DIM-1);
	attribute use_dsp					: string;
	attribute use_dsp of a_data_mult	: signal is "yes";
	signal a_data_mult_pipe				: t_1d_sfix_mult_array(0 to C_CONV_DIM*C_CONV_DIM-1);
	
	-- add bits to avoid using FIXED_SATURATE and avoid overflow
	-- new bitwidth = log2((C_CONV_DIM-1)*(2^old bitwidth-1)) -> new bw = lb(2*(2^12-1)) = 13
	-- C_CONV_DIM-1 additions, +1 for bias addition
	constant C_INTW_SUM1			: integer range 0 to 16 := C_DATA_WIDTH_DATA-C_FRAC_WIDTH_IN+C_DATA_WIDTH_WEIGHTS-C_FRAC_WIDTH_WEIGHTS+1+log2(C_CONV_DIM-1);
	type t_1d_sfix_add_array is array (natural range <>) of sfixed(C_INTW_SUM1-1 downto -C_FRAC_WIDTH_IN-C_FRAC_WIDTH_WEIGHTS);
	signal a_data_mult_resized		: t_1d_sfix_add_array(0 to C_CONV_DIM*C_CONV_DIM-1);
	signal a_data_tmp 				: t_1d_sfix_add_array(0 to C_CONV_DIM-1);
	
	type t_1d_sfix_weights_array is array (natural range <>) of sfixed(C_DATA_WIDTH_WEIGHTS-C_FRAC_WIDTH_WEIGHTS-1 downto -C_FRAC_WIDTH_WEIGHTS);
	signal a_sfix_weights			: t_1d_sfix_weights_array(0 to C_CONV_DIM*C_CONV_DIM-1);
	
	constant C_INTW_SUM2			: integer range 0 to 16 := C_INTW_SUM1+log2(C_CONV_DIM-1); -- C_CONV_DIM-1 additions
	signal sfix_data_conv			: sfixed(C_INTW_SUM2-1 downto -C_FRAC_WIDTH_IN-C_FRAC_WIDTH_WEIGHTS);

	signal slv_data_out				: std_logic_vector(C_INTW_SUM2+C_FRAC_WIDTH_IN+C_FRAC_WIDTH_WEIGHTS-1 downto 0);
	signal sl_output_valid		: std_logic := '0';

	-- debug
	-- type t_2d_slv_array is array (natural range <>, natural range <>) of std_logic_vector(C_DATA_WIDTH_WEIGHTS - 1 downto 0);
	-- signal a_conv_weights			: t_2d_slv_array(0 to C_CONV_DIM - 1,0 to C_CONV_DIM - 1);

begin
	-------------------------------------------------------
	-- Process: Convolution
	-------------------------------------------------------
	process(isl_clk)
	variable v_sfix_conv_res : t_1d_sfix_add_array(0 to C_CONV_DIM-1);
	variable v_sfix_data_out : sfixed(C_INTW_SUM2-1 downto -C_FRAC_WIDTH_IN-C_FRAC_WIDTH_WEIGHTS) := (others => '0');
	begin
		if rising_edge(isl_clk) then
			if (isl_ce = '1') then
				
				-- Stage 1: Load Weights and Data
				-- Stage 2: 9x Mult / 1x Mult + Add Bias
				-- Stage 3: Pipeline DSP output
				-- Stage 4: 9x Resize
				-- Stage 5: 2x Add / 1x Add
				-- Stage 6: 2x Add / 1x Add (theoretically not needed for 1x1 conv)
				-- Total: 3x3 Convolution / 1x1 Convolution
				
				-- stages
				slv_stage <= isl_valid & slv_stage(slv_stage'LOW to slv_stage'HIGH-1);
				sl_output_valid <= slv_stage(slv_stage'HIGH);
				
				-- Stage 1
				if (isl_valid = '1') then
					for j in 0 to C_CONV_DIM-1 loop
						for i in 0 to C_CONV_DIM-1 loop
							a_sfix_data(i+j*C_CONV_DIM) <= to_sfixed(islv_data(((i+1)+j*C_CONV_DIM)*C_DATA_WIDTH_DATA-1 downto 
								(i+j*C_CONV_DIM)*C_DATA_WIDTH_DATA),C_DATA_WIDTH_DATA-C_FRAC_WIDTH_IN-1, -C_FRAC_WIDTH_IN);
							a_sfix_weights(i+j*C_CONV_DIM) <= to_sfixed(islv_weights(((i+1)+j*C_CONV_DIM)*C_DATA_WIDTH_WEIGHTS-1 downto 
								(i+j*C_CONV_DIM)*C_DATA_WIDTH_WEIGHTS), C_DATA_WIDTH_WEIGHTS-C_FRAC_WIDTH_WEIGHTS-1, -C_FRAC_WIDTH_WEIGHTS);
						end loop;
					end loop;
				end if;
				
				-- Stage 2
				if (slv_stage(2) = '1') then
					for j in 0 to C_CONV_DIM-1 loop
						for i in 0 to C_CONV_DIM-1 loop
							a_data_mult(i+j*C_CONV_DIM) <=
								a_sfix_data(i+j*C_CONV_DIM) * a_sfix_weights(i+j*C_CONV_DIM);
						end loop;
					end loop;
				end if;
				
				-- Stage 3
				if (slv_stage(3) = '1') then
					a_data_mult_pipe <= a_data_mult;
				end if;
				
				-- Stage 4
				if (slv_stage(4) = '1') then
					for j in 0 to C_CONV_DIM-1 loop
						for i in 0 to C_CONV_DIM-1 loop
							a_data_mult_resized(i+j*C_CONV_DIM) <= resize(
								a_data_mult_pipe(i+j*C_CONV_DIM), 
								C_INTW_SUM1-1, -C_FRAC_WIDTH_IN-C_FRAC_WIDTH_WEIGHTS, fixed_wrap, fixed_truncate);
						end loop;
					end loop;
				end if;
				
				-- Stage 5
				if (slv_stage(5) = '1') then
					for j in 0 to C_CONV_DIM-1 loop
						v_sfix_conv_res(j) := a_data_mult_resized(j*C_CONV_DIM);
						for i in 1 to C_CONV_DIM-1 loop
							v_sfix_conv_res(j) := resize(
								v_sfix_conv_res(j) +
								a_data_mult_resized(i+j*C_CONV_DIM),
								C_INTW_SUM1-1, -C_FRAC_WIDTH_IN-C_FRAC_WIDTH_WEIGHTS, fixed_wrap, fixed_truncate);
						end loop;
					end loop;
					a_data_tmp <= v_sfix_conv_res;
				end if;
				
				-- Stage 6
				if (slv_stage(6) = '1') then
					v_sfix_data_out := (others => '0');
					for j in 0 to C_CONV_DIM-1 loop
						v_sfix_data_out := resize(
							v_sfix_data_out + a_data_tmp(j), 
							C_INTW_SUM2-1, -C_FRAC_WIDTH_IN-C_FRAC_WIDTH_WEIGHTS, fixed_wrap, fixed_truncate);
					end loop;
					slv_data_out <= to_slv(v_sfix_data_out);
				end if;
			end if;
		end if;
	end process;

	oslv_data <= slv_data_out;
	osl_valid <= sl_output_valid;
end behavioral;
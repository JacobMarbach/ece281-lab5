--+----------------------------------------------------------------------------
--|
--| NAMING CONVENSIONS :
--|
--|    xb_<port name>           = off-chip bidirectional port ( _pads file )
--|    xi_<port name>           = off-chip input port         ( _pads file )
--|    xo_<port name>           = off-chip output port        ( _pads file )
--|    b_<port name>            = on-chip bidirectional port
--|    i_<port name>            = on-chip input port
--|    o_<port name>            = on-chip output port
--|    c_<signal name>          = combinatorial signal
--|    f_<signal name>          = synchronous signal
--|    ff_<signal name>         = pipeline stage (ff_, fff_, etc.)
--|    <signal name>_n          = active low signal
--|    w_<signal name>          = top level wiring signal
--|    g_<generic name>         = generic
--|    k_<constant name>        = constant
--|    v_<variable name>        = variable
--|    sm_<state machine type>  = state machine type definition
--|    s_<signal name>          = state name
--|
--+----------------------------------------------------------------------------
--|
--| ALU OPCODES:
--|     ADD     000
--|     SUB     001
--|     AND     010
--|     OR      011
--|     R SHIFT 100 
--|     L SHIFT 101
--+----------------------------------------------------------------------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;


entity ALU is
    port(   i_A         :   in std_logic_vector(8 downto 0);
            i_B         :   in std_logic_vector(8 downto 0);
            i_op        :   in std_logic_vector(2 downto 0);
            o_flags     :   out std_logic_vector(2 downto 0);
            o_result    :   out std_logic_vector(7 downto 0)
    );
end ALU;

architecture behavioral of ALU is 
  
	-- declare components and signals
    signal sum, s_and, s_or, s_shift, s_B, s_opcode, s_mux : std_logic_vector(8 downto 0); 
    signal o_Z, o_Cout, o_N : std_logic;
    
begin
	-- PORT MAPS ----------------------------------------
	s_B <=    i_B when i_op = "000" else
	          (not i_B) when i_op = "001" else
	          "000000000";
	s_opcode <=    "000000001" when i_op(0) = '1' else
	               "000000000";
	                         
    sum <= std_logic_vector(signed(i_A) + signed(s_B) + signed(s_opcode));
    s_and <= i_A and i_B;
    s_or <= i_A or i_B;
    
    s_shift <=  std_logic_vector(shift_right(unsigned(i_A), to_integer(unsigned(i_B(2 downto 0))))) when i_op = "100" else
                std_logic_vector(shift_left(unsigned(i_A), to_integer(unsigned(i_B(2 downto 0)))))  when i_op = "101" else
                "000000000";
    s_mux <= sum when (i_op = "000" or i_op = "001") else
             s_and when (i_op = "010") else 
             s_or when (i_op = "011") else
             s_shift when (i_op = "100" or i_op = "101") else
             "000000000";
             
	o_N <= s_mux(7);
	o_Z <= '1' when s_mux = "000000000" else
	       '0';
	o_Cout <= s_mux(8);
	-- CONCURRENT STATEMENTS ----------------------------
	o_flags(2) <= o_N;
	o_flags(1) <= o_Z;
	o_flags(0) <= o_Cout;
	
	o_result <= s_mux(7 downto 0);
	
	
end behavioral;

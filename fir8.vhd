-- 8-tap low-pass FIR filter, 8-bit signed input and output.
-- Q1.7 fixed-point coefficients, 16-bit products, 19-bit sum.
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fir8 is
  port (
    clk  : in  std_logic;
    rst  : in  std_logic;
    x_in : in  signed(7 downto 0);
    y_out: out signed(7 downto 0)
  );
end fir8;

architecture rtl of fir8 is
  constant N : integer := 8;
  type coef_t  is array (0 to N-1) of signed(7 downto 0);
  type delay_t is array (0 to N-1) of signed(7 downto 0);
  type prod_t  is array (0 to N-1) of signed(15 downto 0);

  constant COEF : coef_t := (
    to_signed(-1, 8), to_signed(1, 8),  to_signed(18, 8), to_signed(46, 8),
    to_signed(46, 8), to_signed(18, 8), to_signed(1, 8),  to_signed(-1, 8));

  signal delay : delay_t := (others => (others => '0'));
  signal prod  : prod_t;
  signal acc   : signed(18 downto 0);
begin

  -- Delay line: a shift register with one tap per coefficient
  p_delay : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        delay <= (others => (others => '0'));
      else
        delay(0) <= x_in;
        for i in 1 to N-1 loop
          delay(i) <= delay(i-1);
        end loop;
      end if;
    end if;
  end process;

  -- Parallel multiplications, one per coefficient
  g_mult : for i in 0 to N-1 generate
    prod(i) <= delay(i) * COEF(i);
  end generate;

  -- Sum of the products
  p_sum : process (prod)
    variable s : signed(18 downto 0);
  begin
    s := (others => '0');
    for i in 0 to N-1 loop
      s := s + resize(prod(i), 19);
    end loop;
    acc <= s;
  end process;

  -- Scaling by 128 with saturation, then the output register
  p_out : process (clk)
    variable r : signed(18 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        y_out <= (others => '0');
      else
        r := shift_right(acc, 7);
        if r > 127 then
          y_out <= to_signed(127, 8);
        elsif r < -128 then
          y_out <= to_signed(-128, 8);
        else
          y_out <= resize(r, 8);
        end if;
      end if;
    end if;
  end process;

end rtl;

-- ============================================================
-- Testbench
-- ============================================================
-- Testbench: reads input.txt, applies one sample per clock edge, writes output.txt
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use STD.textio.all;

entity tb_fir8 is
end tb_fir8;

architecture sim of tb_fir8 is
  constant T : time := 10 ns;
  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal x_in  : signed(7 downto 0) := (others => '0');
  signal y_out : signed(7 downto 0);
  signal done  : boolean := false;
begin

  dut : entity work.fir8
    port map (clk => clk, rst => rst, x_in => x_in, y_out => y_out);

  clk <= not clk after T/2 when not done else '0';

  stim : process
    file fin  : text open read_mode  is "input.txt";
    file fout : text open write_mode is "output.txt";
    variable l  : line;
    variable v  : integer;
    variable lo : line;
  begin
    wait for 2*T;
    rst <= '0';
    while not endfile(fin) loop
      readline(fin, l);
      read(l, v);
      x_in <= to_signed(v, 8);
      wait until rising_edge(clk);
      wait for 1 ns;
      write(lo, integer'image(to_integer(y_out)));
      writeline(fout, lo);
    end loop;
    -- flush the delay line
    for k in 1 to 4 loop
      x_in <= (others => '0');
      wait until rising_edge(clk);
      wait for 1 ns;
    end loop;
    done <= true;
    wait;
  end process;

end sim;

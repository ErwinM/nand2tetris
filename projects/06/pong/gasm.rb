class String
  def is_num?
    /\A[-+]?\d+\z/ === self
  end
end

class Instruction
  attr_accessor :type, :command, :dest, :is_symbol, :jump

  def initialize(type, command, dest)
    @type = type
    @command = command
    @dest = dest
  end

  def push
    $command_table[$line_nr]=self
    $line_nr +=1
  end

end

class Symboll
  attr_accessor :name, :address, :type

  def initialize(name, type)
    @name = name
    @address = address
    @type = type
  end

  def push
    #does the symbol already exist?
    if Symboll.find(self.name) then
      if self.type == "l_command" then
        puts "triggered!"
        existing_key = Symboll.find_index(self)
        $sym_table.delete(existing_key)
        self.address = $line_nr
        $sym_table[existing_key] = self
        return
      else
        puts " - exists"
        return
      end
    end

    #is it a label?
    if self.type == "l_command" then
      self.address = $line_nr
    end

    #add the symbol to the table
    $sym_table[$sym_nr] = self
    $sym_nr +=1
  end

  def self.find(name)
    $sym_table.each do |nr, symbol|
      return symbol if symbol.name == name
    end
    return false
  end

  def self.find_resolved(name)
    $sym_table_resolved.each do |nr, symbol|
      return symbol if symbol.name == name
    end
    return false
  end

  def self.find_index(symbol)
    # clients.select{|key, hash| hash["client_id"] == "2180" }
    matches = $sym_table.find{ |index, symboll| symboll.name == symbol.name }
    puts "matches: #{matches[0]}"
    return matches[0]
  end

  def self.load_predefined
    PREDEFINED.each do |key, addr|
      s= Symboll.new(key, "a_command")
      s.address = addr
      $sym_table[$sym_nr] = s
      $sym_nr +=1
    end
  end

  PREDEFINED= {
    "SP"  => 0,
    "LCL" => 1,
    "ARG" => 2,
    "THIS"=> 3,
    "THAT"=> 4,
    "SCREEN"=> 16384,
    "KBD" => 24576,
    "R0"  => 0,
    "R1"  => 1,
    "R2"  => 2,
    "R3"  => 3,
    "R4"  => 4,
    "R5"  => 5,
    "R6"  => 6,
    "R7"  => 7,
    "R8"  => 8,
    "R9"  => 9,
    "R10"  => 10,
    "R11"  => 11,
    "R12"  => 12,
    "R13"  => 13,
    "R14"  => 14,
    "R15"  => 15,
  }
end

class Translate

  COMP_MNEMONIC= {
    "0"   => "0101010",
    "1"   => "0111111",
    "-1"  => "0111010",
    "D"   => "0001100",
    "A"   => "0110000",
    "!D"  => "0001101",
    "!A"  => "0110001",
    "-D"  => "0001111",
    "-A"  => "0110011",
    "D+1" => "0011111",
    "A+1" => "0110111",
    "D-1" => "0001110",
    "A-1" => "0110010",
    "D+A" => "0000010",
    "D-A" => "0010011",
    "A-D" => "0000111",
    "D&A" => "0000000",
    "D|A" => "0010101",
    "M"   => "1110000",
    "!M"  => "1110001",
    "-M"  => "1110011",
    "M+1" => "1110111",
    "M-1" => "1110010",
    "D+M" => "1000010",
    "D-M" => "1010011",
    "M-D" => "1000111",
    "D&M" => "1000000",
    "D|M" => "1010101"
  }

  DEST_MNEMONIC={
    0 => "000",
    "M"    => "001",
    "D"    => "010",
    "MD"   => "011",
    "A"    => "100",
    "AM"   => "101",
    "AD"   => "110",
    "AMD"  => "111"
  }

  JUMP_MNEMONIC={
    0 => "000",
    "JGT" => "001",
    "JEQ" => "010",
    "JGE" => "011",
    "JLT" => "100",
    "JNE" => "101",
    "JLE" => "110",
    "JMP" => "111"
  }

  def self.comp(comp)
    return COMP_MNEMONIC[comp]
  end

  def self.dest(comp)
    return DEST_MNEMONIC[comp]
  end

  def self.jump(comp)
    return JUMP_MNEMONIC[comp]
  end
end

def first_parse(file)
  Symboll.load_predefined
  file.readlines.each do |line|
    line.strip!
    if line.size == 0 then
      # skip empty lines
      next
    end
    instruction = parse_line(line)
    if instruction
      if instruction.type!="l_command" then
        instruction.push
        puts "Pushing command: #{instruction.type}"
      end
      unless instruction.command.is_num? || instruction.type == "c_command" then
        instruction.is_symbol = true
        symbol = Symboll.new(instruction.command, instruction.type)
        symbol.push
        puts "Pushing symbol: #{symbol.name} #{symbol.address}"
      end
    end
   end
end

def resolve_symbols()
  i = 0
  $sym_table.each do |nr, symbol|
    if !symbol.address
      symbol.address = $mem_pointer
      $mem_pointer += 1
    end
    $sym_table_resolved[i] = symbol
    i += 1
  end
end

def second_parse(output)
  $command_table.each do |line, instr|
    mcode = ""

    if instr.type == "c_command" then
      mcode = "111" + Translate.comp(instr.command) + Translate.dest(instr.dest)
      if instr.jump
        mcode += Translate.jump(instr.jump)
      else
        mcode += "000"
      end
    else # a_command
      mcode = "000"
      if instr.is_symbol then
        if !Symboll.find_resolved(instr.command)
          puts "Cannot find symbol in table - #{instr.command}"
          dump_sym_table($sym_table_resolved)
          exit
        end
        addr = Symboll.find_resolved(instr.command).address
      else
        addr = instr.command.to_i
      end
      mcode += "%013b" % addr
    end
    puts mcode
    output.write(mcode)
    output.write("\n")
  end
end

def parse_line(line)
  puts "Parsing: #{line[0]}"
  if line[0..1]=="//" then
    puts "Skipping comment"
    return nil
  end
  if line[0]=="@" then
    line.slice!(0)
    return build_instruction("a_command", line, 0)
  end
  if line[0]=="(" then
    line.slice!(0)
    line.chop!
    return build_instruction("l_command", line, 0)
  end
  if line.include?(";") then
    command, jump = line.split(";")
    instr = Instruction.new("c_command", command, 0)
    instr.jump = jump
    return instr
  end
  # should be a c-instruction - is it?
  if !line.include?("=") then
    puts "Instruction expected on line: #{@line}"
    puts line.size
    exit
  end
  dest, command = line.split("=")
  return build_instruction("c_command", command, dest)
end

def build_instruction(type, command, dest)
  return Instruction.new(type, command, dest)
end

def dump_sym_table(sym_table)
  puts "- SYMBOL TABLE -----"
  sym_table.each do |nr, symbol|
    puts "#{nr} - #{symbol.name} - #{symbol.type} - #{symbol.address}"
  end
end


args = Hash[ ARGV.join(' ').scan(/--?([^=\s]+)(?:=(\S+))?/) ]
file_name = args["f"]
file = File.open(file_name, "r")
output = File.open("A.hack", "w+")

$command_table = {}
$sym_table = {}
$sym_table_resolved = {}
$line_nr = 0
$sym_nr = 0
$mem_pointer = 16

first_parse(file)
resolve_symbols()
second_parse(output)

puts "- COMMAND TABLE -----"
$command_table.each do |line, instruction|
  if instruction.type=="c_command" then
    if instruction.jump then
      puts "#{line}, #{instruction.command};#{instruction.jump} (#{instruction.type})"
    else
      puts "#{line}, #{instruction.dest}=#{instruction.command} (#{instruction.type})"
    end
  elsif instruction.type=="a_command" then
    puts "#{line}, #{instruction.command} #{instruction.is_symbol} - (#{instruction.type})"
  else
    puts "#{line}, #{instruction.command} - (l_command)"
  end
end

dump_sym_table($sym_table_resolved)




class Parser
  attr_reader :file
  attr_accessor :line, :total_lines

  def initialize(file)
    @file=file
    @@line=0
    @total_lines=file.readlines.size
    puts "File has #{@total_lines.to_s} lines."
  end

  def hasMoreCommands?
    line == total_lines
  end

  def parse_line(line)
    # a or c instruction
    if line[0..1]=="//" then
      puts "Skipping comment"
      return nil
    end
    if line[0]=="@" then
      line.slice!(0)
      instr = Instruction.new("a_command", line, 0)
      unless is_number?(instr.command) then
        @@symtable.push(instr.command, instr.type, @@line)
        puts "Found symbol"
      end
      return instr
    end
    if line[0]=="(" then
      line.slice!(0)
      line.chop!
      instr = Instruction.new("l_command", line, 0)
      @@symtable.push(instr.command, instr.type, @@line)
      return instr
    end
    # should be a c-instruction - is it?
    if !line.include?("=") then
      puts "Instruction expected on line: #{@line}"
      puts line.size
      exit
    end
    dest, command = line.split("=")
    return Instruction.new("c_command", command, dest)
  end

  def parse
    file.rewind
    parsed_file = {}

    file.readlines.each do |line|
      @@line+=1
      line.strip!
      if line.size == 0 then
        next
      end
      instr = parse_line(line)
      if instr then
        parsed_file[@line] = instr
      end
    end
    return parsed_file
  end

  def is_number?(value)
    /\A[-+]?\d+\z/ === value
  end
end

class Instruction
  attr_accessor :line, :type, :command, :dest, :is_symbol

  def initialize(type, command, dest)
    @type = type
    @command = command
    @dest = dest
  end
end

class SymbolEntry
  attr_accessor :name, :address, :type

  def initialize(name, address, type)
    @name = name
    @address = address
    @type = type
  end
end

class SymbolTable
  attr_accessor :mem_pointer, :counter, :table

  def initialize(dbase)
    @mem_pointer = dbase
    @table = {}
    @counter = 0
  end

  def push(name, type, line)
    # check if symbol is already in table
    return if symbol_exists?(name)
    if type == "l_command" then
      address = line+1
    else
      address = @mempointer
    end
    s = SymbolEntry.new(name, address, type)
    @table[@counter]=s
    @counter +=1
    @mem_pointer +=1
  end

  def symbol_exists?(symbol_name)
    @table.each do |nr, symbol|
      return true if symbol.name == symbol_name
    end
    return false
  end


end

class Compiler
end


args = Hash[ ARGV.join(' ').scan(/--?([^=\s]+)(?:=(\S+))?/) ]
file_name = args["f"]
file = File.open(file_name, "r")

@@symtable = SymbolTable.new(0)

p = Parser.new(file)
pf = {}
pf = p.parse

pf.each do |line, instruction|
  if instruction.type=="c_command" then
    puts "#{line}, #{instruction.dest}=#{instruction.command} (#{instruction.type})"
  else
    puts "#{instruction.command}   (#{instruction.type})"
  end
end

@@symtable.table.each do |nr, symbol|
  puts "#{nr} - #{symbol.name} - #{symbol.type} - #{symbol.address}"
end









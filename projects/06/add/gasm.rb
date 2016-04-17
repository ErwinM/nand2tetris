class String
  def is_num?
    /\A[-+]?\d+\z/ === self
  end
end

def first_parse(file)
  file.readlines.each do |line|
    line.strip!
    if line.size == 0 then
      # skip empty lines
      next
    end
    instruction_hash = parse_line(line)
    if instruction_hash
      if instruction_hash[:type]!="l_command" then
        push_command(instruction_hash)
        puts "Pushing command: #{instruction_hash}"
      end
      unless instruction_hash[:command].is_num? || instruction_hash[:type] == "c_command" then
        push_symbol(instruction_hash)
        puts "Pushing symbol: #{instruction_hash}"
      end
    end
   end
end

def parse_line(line)
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
  return { :type => type, :command => command, :dest => dest }
end

def push_command(instruction_hash)
  $command_table[$line_nr]=instruction_hash
  $line_nr +=1
end

def push_symbol(instruction_hash)
  return if symbol_exists?(instruction_hash[:command])
  if instruction_hash[:type] == "l_command" then
    address = $line_nr-1 # -1 because mem base is 0
  else
    address = $mem_pointer
    $mem_pointer += 1
  end
  $sym_table[$sym_nr]={:name => instruction_hash[:command], :address => address, :type => instruction_hash[:type]}
  $sym_nr +=1
end

def symbol_exists?(symbol_name)
  $sym_table.each do |nr, symbol|
    return true if symbol[:name] == symbol_name
  end
  return false
end


args = Hash[ ARGV.join(' ').scan(/--?([^=\s]+)(?:=(\S+))?/) ]
file_name = args["f"]
file = File.open(file_name, "r")

$command_table = {}
$sym_table = {}
$line_nr = 1
$sym_nr = 0
$mem_pointer = 0

first_parse(file)

puts "- COMMAND TABLE -----"
$command_table.each do |line, instruction_hash|
  if instruction_hash[:type]=="c_command" then
    puts "#{line}, #{instruction_hash[:dest]}=#{instruction_hash[:command]} (#{instruction_hash[:type]})"
  else
    puts "#{line}, #{instruction_hash[:command]} - (#{instruction_hash[:type]})"
  end
end

puts "- SYMBOL TABLE -----"
$sym_table.each do |nr, symbol_hash|
  puts "#{nr} - #{symbol_hash[:name]} - #{symbol_hash[:type]} - #{symbol_hash[:address]}"
end

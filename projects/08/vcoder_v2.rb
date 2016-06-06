class Instruction
  attr_accessor :type, :arg1, :arg2

  def initialize(type)
    @type = type
  end

  def push
    $instr_table[$instr_index]=self
    $instr_index +=1
  end
end

class Parser

  ARITHMETIC_COMMANDS = %w{add sub neg eq gt lt and or not}
  OTHER_COMMANDS = {
    "pop" => :C_POP,
    "push" => :C_PUSH,
    "label" => :C_LABEL,
    "goto" => :C_GOTO,
    "if-goto" => :C_IF,
    "function" => :C_FUNCTION,
    "return" => :C_RETURN,
    "call" => :C_CALL
  }

  MEM_SEGMENTS = %w{ pointer static constant that this argument local temp }


   # C_ARITHMETIC, C_PUSH, C_POP, C_LABEL, C_GOTO, C_IF, C_FUNCTION, C_RETURN, C_CALL

  def self.parse(file)
    file.readlines.each do |line|
      line.strip!
      if line.size == 0 then
        next # skip empty lines
      end
      instr = Parser.parse_line(line)
      if instr
        instr.push
      end
    end
  end

  def self.parse_line(line)
    puts "Parsing: #{line}\n"
    if line[0..1] == "//" then
      return nil
    end
    command, arg1, arg2 = line.split(" ")
    puts OTHER_COMMANDS.class
    if ARITHMETIC_COMMANDS.include?(command) then
      instr = Instruction.new(:C_ARITHMETIC)
      instr.arg1 = command
      return instr
    elsif OTHER_COMMANDS.has_key?(command) then
      instr = Instruction.new(OTHER_COMMANDS[command])
      instr.arg1 = arg1
      instr.arg2 = arg2
      if command == "pop" || command == "push"
        unless MEM_SEGMENTS.include?(arg1) then
          puts "push: unknown segment reference"
          exit
        end
      end
      return instr
    else
      puts "Parser: unknown command: #{command}"
      exit
    end
  end

  def self.dump_instr_table(table)
    table.each do |index, instr|
      puts "#{index}, #{instr.type}, #{instr.arg1} #{instr.arg2}"
    end
  end
end

class CodeWriter

  def self.output(table, output)
    code = CodeWriter.write_init()
    output.write(code)
    table.each do |index, instr|
      code = CodeWriter.write(instr)
      output.write(code)
    end
  end

  def self.write(instr)
    case instr.type
    when :C_PUSH
      code = CodeWriter.write_push(instr)
    when :C_POP
      code = CodeWriter.write_pop(instr)
    when :C_ARITHMETIC
      code = CodeWriter.write_arithmetic(instr.arg1)
    when :C_LABEL
      code = CodeWriter.write_label(instr)
    when :C_GOTO
      code = CodeWriter.write_goto(instr)
    when :C_IF
      code = CodeWriter.write_if(instr)
    else
      puts "CodeWriter.write: unknown command word"
      exit
    end
    return code
  end

  def self.write_arithmetic(command)
    if %w{ add sub and or }.include?(command) then
      # 2 operand instruction
      # x is in sp - 2, y = in y - 1
      # get x in D and Y in M(via A)
      code = <<-eos
@2
D=A
@SP
A=M-D
D=M
@SP
A=M-1
eos
      case command
      when "add"
        code += "D=D+M\n"
      when "sub"
        code += "D=D-M\n"
      when "and"
        code += "D=D&M\n"
      when "or"
        code += "D=D|M\n"
      end
      # point to sp - 2
      # M = D
      # SP = SP - 1
      code += <<-eos
A=A-1
M=D
@SP
M=M-1
eos
    end
    if %w{ neg not }.include?(command) then
      code = <<-eos
@SP
A=M-1
eos
      case command
      when "neg"
        code += "D=-M\n"
      when "not"
        code += "D=!M\n"
      end
      # M is already pointing to sp - 1
      # M = D
      # SP can remain
      code += "M=D\n"
    end
    if %w{ eq gt lt}.include?(command) then
      # 2 operand instruction
      # x is in sp - 2, y = in y - 1
      # get x in D and Y in M(via A)
      label_true = "_branch_jmp_true_"+$int_branch_nr.to_s
      label_exit = "_branch_jmp_exit_"+$int_branch_nr.to_s
      $int_branch_nr += 1
      code = <<-eos
@2
D=A
@SP
A=M-D
D=M
@SP
A=M-1
D=D-M
@#{label_true}
eos
      case(command)
      when "eq"
        code += "D;JEQ\n"
      when "gt"
        code += "D;JGT\n"
      when "lt"
        code += "D;JLT\n"
      end
      code +=<<-eos
@2
D=A
@SP
A=M-D
M=0
@#{label_exit}
0;JMP
(#{label_true})
@2
D=A
@SP
A=M-D
M=-1
(#{label_exit})
@SP
M=M-1
eos
    end
    return code
  end



  def self.write_push(instr)
    # get the value to be pushed in reg D
    # depending on the segment declaration
    if instr.arg1 == "constant" then
      code = <<-eos
@#{instr.arg2.to_s}
D=A
eos
    elsif %w{ local argument this that}.include?(instr.arg1) then
      case(instr.arg1)
      when "local"
        code = "@LCL\n"
      when "argument"
        code = "@ARG\n"
      when "this"
        code = "@THIS\n"
      when "that"
        code = "@THAT\n"
      end
      case(instr.arg2.to_i)
      when 0
        code += <<-eos
A=M
D=M
eos
      when 1
        code += <<-eos
A=M+1
D=M
eos
      else
        code += <<-eos
D=M
@R13
M=D
@#{instr.arg2.to_s}
D=A
@R13
A=D+M
D=M
eos
      end
    elsif instr.arg1 == "pointer" then
      code = <<-eos
@R#{(3 + instr.arg2.to_i).to_s}
D=M
eos
    elsif instr.arg1 == "temp" then
      code = <<-eos
@R#{(5 + instr.arg2.to_i).to_s}
D=M
eos
    elsif instr.arg1 == "static" then
      mem_loc = instr.arg2.to_i + 16 # static is mem locs 16 - 255
      if mem_loc < 16 || mem_loc > 255 then
        puts "push: static offset must be between 0 and 239"
        exit
      end
      code = <<-eos
@#{mem_loc.to_s}
D=M
eos
    end
    # push the contents of D on the stack
    # and increase SP
    code += <<-eos
@SP
A=M
M=D
@SP
M=M+1
eos
    return code
  end

  def self.write_pop(instr)
    # get the top stack value in D
    # will not get used if offset > 1
    code = <<-eos
@SP
A=M-1
D=M
eos
    if %w{ argument local this that}.include?(instr.arg1) then
      case(instr.arg1)
      when "local"
        code += "@LCL\n"
      when "argument"
        code += "@ARG\n"
      when "this"
        code += "@THIS\n"
      when "that"
        code += "@THAT\n"
      end
      case(instr.arg2.to_i)
      when 0
        code += <<-eos
A=M
M=D
eos
      when 1
        code += <<-eos
A=M+1
M=D
eos
      else
        code += <<-eos
D=M
@R13
M=D
@#{instr.arg2.to_s}
D=A
@R13
M=D+M
@SP
A=M-1
D=M
@R13
A=M
M=D
eos
      end
    elsif instr.arg1 == "static" then
      mem_loc = instr.arg2.to_i + 16 # static is mem locs 16 - 255
      if mem_loc < 16 || mem_loc > 255 then
        puts "pop: static offset must be between 0 and 239"
        exit
      end
      code += <<-eos
@SP
A=M-1
D=M
@#{mem_loc}
M=D
eos
    elsif instr.arg1 == "temp" then
      mem_loc = instr.arg2.to_i + 5
      if mem_loc < 5 || mem_loc > 12 then
        puts "pop: temp offset must be between 0 and 8"
        exit
      end
      code += <<-eos
@SP
A=M-1
D=M
@#{mem_loc}
M=D
eos
    elsif instr.arg1 == "pointer" then
      code += <<-eos
@SP
A=M-1
D=M
@R#{3 + instr.arg2.to_i}
M=D
eos
    end
    # decrease stack pointer
    code += <<-eos
@SP
M=M-1
eos
  end

  def self.write_label(instr)
    code = "(#{instr.arg1})\n"
    return code
  end

  def self.write_goto(instr)
    code = <<-eos
@#{instr.arg1}
0;JMP
eos
  end

  def self.write_if(instr)
    # pop top value from stack
    # jump if not zero
    code = <<-eos
@SP
A=M-1
D=M
@SP
M=M-1
@#{instr.arg1}
D;JNE
eos
  end

  def self.write_init()
    code = ""
    code += "@" + $stack_base.to_s + "\n"
    code += "D=A\n"
    code += "@SP\n"
    code += "M=D\n"
    return code
  end

end

class Compiler
end

args = Hash[ ARGV.join(' ').scan(/--?([^=\s]+)(?:=(\S+))?/) ]
file_name = args["f"]
file = File.open(file_name, "r")
output = File.open("A.asm", "w+")

$instr_table = {}
$instr_index = 0

$int_branch_nr = 0
#$static_var_loc = 16   # 16-255

$stack_base = 256 # grows up?


Parser.parse(file)
Parser.dump_instr_table($instr_table)

CodeWriter.output($instr_table, output)

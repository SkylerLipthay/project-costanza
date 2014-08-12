require 'oily_png'
require 'set'

def unescape_c_string(s)
  state = 0
  res = ''
  s.each_char { |c|
    case state
    when 0
      case c
      when "\\" then state = 1
      else res << c
      end
    when 1
      case c
      when 'n' then res << "\n"; state = 0
      when 't' then res << "\t"; state = 0
      when "\\" then res << "\\"; state = 0
      else res << c; state = 0
      end      
    end
  }
  return res
end

class Label
  attr_accessor :address
end

class Instruction
  attr_accessor :line
  attr_accessor :address

  def length
    # override
    0
  end

  def parse(tokens, program)
    # override
    true
  end

  def parse_line(line, program)
    # override
    true
  end

  def second_pass(program)
    # override
    # all labels have been recorded at this point
    true
  end

  def packed
    # override
    nil
  end
end

class Program
  attr_accessor :instructions
  attr_accessor :labels
  attr_accessor :address
  attr_accessor :label_lines

  def initialize
    @instructions = []
    @labels = {}
    @address = 0
    @label_lines = Set.new
  end
end

class LabelParser
  def self.verify_label(token)
    return !(token =~ /^([A-Za-z_][A-Za-z0-9_]*)$/).nil?
  end

  def self.read_label(token, program)
    match = token =~ /^([A-Za-z_][A-Za-z0-9_]*)$/
      if !match.nil?
        label = program.labels[token]
        if !label.nil?
          return label.address
        end
      end

    nil
  end
end

class NumberParser
  def self.read_number(token, mask = 0xFFFF)
    match = token =~ /^[-+]?[0-9]+$/
    if !match.nil?
      return !mask.nil? ? token.to_i(10) & mask : token.to_i(10)
    end

    match = token =~ /^(0x[A-Fa-f0-9]+)$/
    if !match.nil?
      return !mask.nil? ? token[2..-1].to_i(16) & mask : token[2..-1].to_i(16)
    end

    match = token =~ /^(0b[0-1]+)$/
    if !match.nil?
      return !mask.nil? ?  token[2..-1].to_i(2) & mask :  token[2..-1].to_i(2)
    end

    nil
  end
end

class RegisterParser
  REGISTERS = {
    'RA' => 0,
    'RB' => 1,
    'RC' => 2,
    'RD' => 3,
    'RE' => 4,
    'RF' => 5,
    'RMH' => 6,
    'RML' => 7,
    'J1' => 8,
    'J2' => 9,
    'RG' => 10,
    'RH' => 11,
    'RX' => 12,
    'RY' => 13,
    'R0' => 14,
    'R1' => 15
  }

  def self.read_register(token)
    return REGISTERS[token]
  end
end

class InstructionMove < Instruction
  def initialize
    @length = 0
  end

  def length
    @length
  end

  def packed
    if @length == 1
      return [0b00000000, @data_dest << 4 | @data_src].pack('CC')
    elsif @length == 2
      return [0b00000001, @data_dest << 4, @data_src].pack('CCS>')
    end
  end

  def parse(tokens, program)
    if tokens.length != 3
      return false
    end

    token_dest = tokens[1]
    token_src = tokens[2]

    @data_dest = RegisterParser.read_register(token_dest)
    if @data_dest.nil?
      return false
    end

    @data_src = RegisterParser.read_register(token_src)
    if @data_src.nil?
      @data_src = NumberParser.read_number(token_src)
      if @data_src.nil?
        return false
      end
      @length = 2
    else
      @length = 1
    end

    if @length == 1 && @data_dest == @data_src
      return false
    end

    true
  end
end

class InstructionLoad < Instruction
  def length
    1
  end

  def packed
    [0b00000010, @data << 4].pack('CC')
  end

  def parse(tokens, program)
    if tokens.length != 2
      return false
    end

    @data = RegisterParser.read_register(tokens[1])
    if @data.nil?
      return false
    end

    true
  end
end

class InstructionStore < InstructionLoad
  def packed
    [0b00000011, @data << 4].pack('CC')
  end
end

class InstructionLoadEffectiveAddress < Instruction
  def length
    1
  end

  def packed
    [0b00000100, 0].pack('CC')
  end

  def parse(tokens, program)
    if tokens.length != 1
      return false
    end

    true
  end
end

class InstructionBranch < Instruction
  def length
    1
  end

  def packed
    [0b00010000, 0].pack('CC')
  end

  def parse(tokens, program)
    if tokens.length != 1
      return false
    end

    true
  end
end

class InstructionBranchLess < InstructionBranch
  def packed
    [0b00010001, 0].pack('CC')
  end
end

class InstructionBranchLessEqual < InstructionBranch
  def packed
    [0b00010010, 0].pack('CC')
  end
end

class InstructionBranchGreater < InstructionBranch
  def packed
    [0b00010011, 0].pack('CC')
  end
end

class InstructionBranchGreaterEqual < InstructionBranch
  def packed
    [0b00010100, 0].pack('CC')
  end
end

class InstructionBranchEqual < InstructionBranch
  def packed
    [0b00010101, 0].pack('CC')
  end
end

class InstructionBranchNotEqual < InstructionBranch
  def packed
    [0b00010110, 0].pack('CC')
  end
end

class InstructionBranchBelow < InstructionBranch
  def packed
    [0b00010111, 0].pack('CC')
  end
end

class InstructionBranchBelowEqual < InstructionBranch
  def packed
    [0b00011000, 0].pack('CC')
  end
end

class InstructionBranchAbove < InstructionBranch
  def packed
    [0b00011001, 0].pack('CC')
  end
end

class InstructionBranchAboveEqual < InstructionBranch
  def packed
    [0b00011010, 0].pack('CC')
  end
end

class InstructionJump < Instruction
  # not actually used anymore
  def length
    1
  end

  def parse(tokens, program)
    return tokens.length == 1
  end
end

class InstructionAdd < Instruction
  def length
    1
  end

  def packed
    [0b00110000, @data_dest << 4 | @data_src].pack('CC')
  end

  def parse(tokens, program)
    if tokens.length != 3
      return false
    end

    token_dest = tokens[1]
    token_src = tokens[2]

    @data_dest = RegisterParser.read_register(token_dest)
    if @data_dest.nil?
      return false
    end

    @data_src = RegisterParser.read_register(token_src)
    if @data_src.nil?
      return false
    end

    if @data_dest == @data_src
      return false
    end

    true
  end
end

class InstructionSubtract < InstructionAdd
  def packed
    [0b00110001, @data_dest << 4 | @data_src].pack('CC')
  end
end

class InstructionAnd < InstructionAdd
  def packed
    [0b00110010, @data_dest << 4 | @data_src].pack('CC')
  end
end

class InstructionOr < InstructionAdd
  def packed
    [0b00110011, @data_dest << 4 | @data_src].pack('CC')
  end
end

class InstructionXor < InstructionAdd
  def packed
    [0b00110100, @data_dest << 4 | @data_src].pack('CC')
  end
end

class InstructionNot < InstructionLoad
  def packed
    [0b00110101, @data << 4].pack('CC')
  end
end

class InstructionCompare < InstructionAdd
  def packed
    [0b00110110, @data_dest << 4 | @data_src].pack('CC')
  end
end

class InstructionShiftLeft < InstructionLoad
  def packed
    [0b00110111, @data << 4].pack('CC')
  end
end

class InstructionShiftRight < InstructionLoad
  def packed
    [0b00111000, @data << 4].pack('CC')
  end
end

class InstructionRotateLeft < InstructionLoad
  def packed
    [0b00111001, @data << 4].pack('CC')
  end
end

class InstructionRotateRight < InstructionLoad
  def packed
    [0b00111010, @data << 4].pack('CC')
  end
end

class InstructionNegate < InstructionLoad
  def packed
    [0b00111011, @data << 4].pack('CC')
  end
end

class InstructionAddMemoryAddress < Instruction
  def length
    2
  end

  def packed
    return [0b01110100, 0, @data_src].pack('CCS>')
  end

  def parse(tokens, program)
    if tokens.length != 2
      return false
    end

    @data_src = NumberParser.read_number(tokens[1])
    if @data_src.nil?
      return false
    end

    true
  end 
end

class InstructionSubtractMemoryAddress < InstructionAddMemoryAddress
  def packed
    return [0b01110101, 0, @data_src].pack('CCS>')
  end
end

class InstructionStoreStackPointer < InstructionJump
  def packed
    [0b01000000, 0].pack('CC')
  end
end

class InstructionPush < InstructionLoad
  def packed
    [0b01000001, @data << 4].pack('CC')
  end
end

class InstructionPop < InstructionLoad
  def packed
    [0b01000010, @data << 4].pack('CC')
  end
end

class InstructionCall < InstructionJump
  def packed
    [0b01000101, 0].pack('CC')
  end
end

class InstructionReturn < InstructionJump
  def packed
    [0b01000110, 0].pack('CC')
  end
end

class InstructionLoadStackPointer < InstructionJump
  def packed
    [0b01000111, 0].pack('CC')
  end
end

class InstructionNoOperation < InstructionJump
  def packed
    [0b01010000, 0].pack('CC')
  end
end

class InstructionHalt < InstructionJump
  def packed
    [0b01010001, 0].pack('CC')
  end
end

class InstructionHighRead < Instruction
  def length
    2
  end

  def packed
    return [0b01010010, 0, @data & 0b111111111].pack('CCS>')
  end

  def parse(tokens, program)
    if tokens.length != 2
      return false
    end

    @data = NumberParser.read_number(tokens[1])
    if @data.nil?
      return false
    end

    true
  end
end

class InstructionHighWrite < InstructionHighRead
  def packed
    return [0b01010011, 0, @data & 0b111111111].pack('CCS>')
  end
end

class InstructionSoundAddress < Instruction
  def length
    1
  end

  def packed
    return [0b01010100, @data & 0b1].pack('CC')
  end

  def parse(tokens, program)
    if tokens.length != 2
      return false
    end

    @data = NumberParser.read_number(tokens[1])
    if @data.nil?
      return false
    end

    true
  end
end

class InstructionSoundLength < InstructionSoundAddress
  def packed
    return [0b01010101, @data & 0b1].pack('CC')
  end
end

class InstructionSoundRepeat < Instruction
  def length
    1
  end

  def packed
    return [0b01010110, ((@data2 & 0b1) << 1) | (@data & 0b1)].pack('CC')
  end

  def parse(tokens, program)
    if tokens.length != 3
      return false
    end

    @data = NumberParser.read_number(tokens[1])
    if @data.nil?
      return false
    end

    @data2 = NumberParser.read_number(tokens[2])
    if @data2.nil?
      return false
    end

    true
  end
end

class InstructionSoundWrite < InstructionSoundAddress
  def packed
    return [0b01010111, @data & 0b1].pack('CC')
  end
end

class InstructionSoundPlay < InstructionSoundRepeat
  def packed
    return [0b01011000, ((@data2 & 0b1) << 1) | (@data & 0b1)].pack('CC')
  end
end

class InstructionImageDimensions < Instruction
  def length
    2
  end

  def packed
    return [
      0b01011001,
      (@width & 0b110000000) >> 7,
      ((@width & 0b001111111) << 1) | ((@height & 0b100000000) >> 8),
      @height & 0b011111111,
    ].pack('CCCC')
  end

  def parse(tokens, program)
    if tokens.length != 3
      return false
    end

    @width = NumberParser.read_number(tokens[1])
    if @width.nil?
      return false
    end

    if (@width < 1 || @width > 512)
      return false
    end

    @width -= 1

    @height = NumberParser.read_number(tokens[2])
    if @height.nil?
      return false
    end

    if (@height < 1 || @height > 512)
      return false
    end

    @height -= 1

    true
  end
end

class InstructionImageCoordinatesDirect < Instruction
  def length
    2
  end

  def packed
    return [
      0b01011010,
      ((@x_neg & 0b1) << 3) | ((@x & 0b111000000) >> 6),
      ((@x & 0b000111111) << 2) | ((@y_neg & 0b1) << 1) | ((@y & 0b100000000) >> 8),
      @y & 0b011111111,
    ].pack('CCCC')
  end

  def parse(tokens, program)
    if tokens.length != 3
      return false
    end

    @x = NumberParser.read_number(tokens[1], nil)
    if @x.nil?
      return false
    end

    if (@x < -511 || @x > 511)
      puts @x
      return false
    end

    @x_neg = @x < 0 ? 1 : 0
    @x = @x.abs

    @y = NumberParser.read_number(tokens[2], nil)
    if @y.nil?
      return false
    end

    if (@y < -511 || @y > 511)
      return false
    end

    @y_neg = @y < 0 ? 1 : 0
    @y = @y.abs

    true
  end
end

class InstructionImageCoordinates < InstructionJump
  def packed
    [0b01011011, 0].pack('CC')
  end
end

class InstructionImageAddress < InstructionJump
  def packed
    [0b01011100, 0].pack('CC')
  end
end

class InstructionFlip < InstructionJump
  def packed
    [0b01011101, 0].pack('CC')
  end
end

class InstructionLoadMemoryAddress < Instruction
  def length
    4
  end

  def packed
    [
      0b00000001, 6 << 4, (@data & 0xFFFF0000) >> 16,
      0b00000001, 7 << 4, @data & 0x0000FFFF
    ].pack('CCS>CCS>')
  end

  def parse(tokens, program)
    if tokens.length != 2
      return false
    end

    token = tokens[1]

    @is_label = false
    if LabelParser.verify_label(token)
      @data = token
      @is_label = true
      return true
    end

    @data = NumberParser.read_number(token, 0xFFFFFFFF)
    if @data.nil?
      return false
    end

    true
  end

  def second_pass(program)
    if @is_label
      @data = LabelParser.read_label(@data, program)
      return !@data.nil?
    else
      return true
    end
  end
end

class InstructionPushMemoryAddress < InstructionJump
  def length
    2
  end

  def packed
    return [0b01000001, 6 << 4, 0b01000001, 7 << 4].pack('CCCC')
  end
end

class InstructionPopMemoryAddress < InstructionJump
  def length
    2
  end

  def packed
    return [0b01000010, 7 << 4, 0b01000010, 6 << 4].pack('CCCC')
  end
end

class InstructionLoadAccessory < InstructionLoadMemoryAddress
  def packed
    [
      0b00000001, 10 << 4, (@data & 0xFFFF0000) >> 16,
      0b00000001, 11 << 4, @data & 0x0000FFFF
    ].pack('CCS>CCS>')
  end
end

class InstructionPushAccessory < InstructionJump
  def length
    2
  end

  def packed
    return [0b01000001, 10 << 4, 0b01000001, 11 << 4].pack('CCCC')
  end
end

class InstructionPopAccessory < InstructionJump
  def length
    2
  end

  def packed
    return [0b01000010, 11 << 4, 0b01000010, 10 << 4].pack('CCCC')
  end
end

# class InstructionLoadX < Instruction
#   def length
#     2
#   end

#   def packed
#     [
#       0b00000001,
#       12 << 4,
#       ((@neg & 0b1) << 1) | ((@data & 0b100000000) >> 8),
#       @data & 0b011111111
#     ].pack('CCS>')
#   end

#   def parse(tokens, program)
#     if tokens.length != 2
#       return false
#     end

#     @data = NumberParser.read_number(tokens[1], 0xFFFFFFFF)
#     if @data.nil?
#       return false
#     end

#     if (@data < -511 || @data > 511)
#       return false
#     end

#     @neg = @data < 0 ? 1 : 0

#     true
#   end
# end

# class InstructionLoadY < InstructionLoadX
#   def packed
#     [
#       0b00000001,
#       13 << 4,
#       ((@neg & 0b1) << 1) | ((@data & 0b100000000) >> 8),
#       @data & 0b011111111
#     ].pack('CCS>')
#   end
# end

class InstructionRawWord < Instruction
  def length
    1
  end

  def packed
    [@data].pack('S>')
  end

  def parse(tokens, program)
    if tokens.length != 2
      return false
    end

    @data = NumberParser.read_number(tokens[1])
    if @data.nil?
      return false
    end

    true
  end
end

class InstructionRawDword < Instruction
  def length
    2
  end

  def packed
    [@data].pack('L>')
  end

  def parse(tokens, program)
    if tokens.length != 2
      return false
    end

    @data = NumberParser.read_number(tokens[1], 0xFFFFFFFF)
    if @data.nil?
      return false
    end

    true
  end
end

class InstructionRawArray < Instruction
  def length
    @length
  end

  def packed
    @data.pack('S>*')
  end

  def parse(tokens, program)
    if tokens.length < 2
      return false
    end

    @length = 0
    @data = []

    tokens[1..-1].each do |t|
      @length += 1

      number = NumberParser.read_number(t)
      if number.nil?
        return false
      end

      @data.push(number)
    end

    true
  end
end

class InstructionRawString < Instruction
  def length
    @data.length
  end

  def packed
    @data.pack('C*')
  end

  def parse_line(line, program)
    result = /^raws\s*\"(?<string>.*)\"$/.match(line)
    if result.nil?
      return false
    end

    @data = []
    unescape_c_string(result[:string]).each_byte do |b|
      @data.push(b)
    end

    if @data.length % 2 == 1
      @data.push(0)
    end

    true
  end
end

class InstructionRawFile < Instruction
  def length
    @data.length / 2
  end

  def packed
    @data.pack('C*')
  end

  def parse_line(line, program)
    result = /^rawf\s*\"(?<string>.*)\"$/.match(line)
    if result.nil?
      return false
    end

    filename = unescape_c_string(result[:string])
    begin
      contents = File.open(filename, 'rb').read
    rescue Exception => exception
      puts(exception)
      return false
    end

    @data = []
    contents.each_byte do |b|
      @data.push(b)
    end

    if @data.length % 2 == 1
      @data.push(0)
    end

    true
  end
end

class InstructionRawImage < Instruction
  def length
    @data.length
  end

  def packed
    @data.pack('S>*')
  end

  def parse_line(line, program)
    result = /^rawi\s*\"(?<string>.*)\"$/.match(line)
    if result.nil?
      return false
    end

    filename = unescape_c_string(result[:string])

    begin
      image = ChunkyPNG::Image.from_file(filename)
    rescue Exception => exception
      puts(exception)
      return false
    end

    @data = []

    image.height.times do |y|
      image.width.times do |x|
        # 8888 RGBA to 5551 RGBA
        pixel = image[x, y]
        red = ((((pixel & 0xFF000000) >> 24).to_f / 255.0) * 31.0).round
        green = ((((pixel & 0x00FF0000) >> 16).to_f / 255.0) * 31.0).round
        blue = ((((pixel & 0x0000FF00) >> 8).to_f / 255.0) * 31.0).round
        alpha = ((((pixel & 0x000000FF) >> 0).to_f / 255.0) * 1.0).round

        final = (red << 11) | (green << 6) | (blue << 1) | alpha
        @data << final
      end
    end

    true
  end
end

class InstructionDispatch
  INSTRUCTION_TYPES = {
    'mov' => InstructionMove,
    'ld' => InstructionLoad,
    'st' => InstructionStore,
    'lea' => InstructionLoadEffectiveAddress,
    'br' => InstructionBranch,
    'brl' => InstructionBranchLess,
    'brle' => InstructionBranchLessEqual,
    'brg' => InstructionBranchGreater,
    'brge' => InstructionBranchGreaterEqual,
    'bre' => InstructionBranchEqual,
    'brne' => InstructionBranchNotEqual,
    'brb' => InstructionBranchBelow,
    'brbe' => InstructionBranchBelowEqual,
    'bra' => InstructionBranchAbove,
    'brae' => InstructionBranchAboveEqual,
    'add' => InstructionAdd,
    'sub' => InstructionSubtract,
    'and' => InstructionAnd,
    'or' => InstructionOr,
    'xor' => InstructionXor,
    'not' => InstructionNot,
    'cmp' => InstructionCompare,
    'shl' => InstructionShiftLeft,
    'shr' => InstructionShiftRight,
    'rl' => InstructionRotateLeft,
    'rr' => InstructionRotateRight,
    'neg' => InstructionNegate,
    'addma' => InstructionAddMemoryAddress,
    'subma' => InstructionSubtractMemoryAddress,
    'ssp' => InstructionStoreStackPointer,
    'push' => InstructionPush,
    'pop' => InstructionPop,
    'call' => InstructionCall,
    'ret' => InstructionReturn,
    'lsp' => InstructionLoadStackPointer,
    'nop' => InstructionNoOperation,
    'halt' => InstructionHalt,
    'hrd' => InstructionHighRead,
    'hwr' => InstructionHighWrite,
    'snda' => InstructionSoundAddress,
    'sndl' => InstructionSoundLength,
    'sndr' => InstructionSoundRepeat,
    'sndw' => InstructionSoundWrite,
    'sndp' => InstructionSoundPlay,
    'imgd' => InstructionImageDimensions,
    'imgcd' => InstructionImageCoordinatesDirect,
    'imgc' => InstructionImageCoordinates,
    'imga' => InstructionImageAddress,
    'flip' => InstructionFlip,
    # directives
    'lma' => InstructionLoadMemoryAddress,
    'pushma' => InstructionPushMemoryAddress,
    'popma' => InstructionPopMemoryAddress,
    'lacc' => InstructionLoadAccessory,
    'pushacc' => InstructionPushAccessory,
    'popacc' => InstructionPopAccessory,
    # 'ldx' => InstructionLoadX,
    # 'ldy' => InstructionLoadY,
    'raww' => InstructionRawWord,
    'rawd' => InstructionRawDword,
    'rawa' => InstructionRawArray,
    'raws' => InstructionRawString,
    'rawf' => InstructionRawFile,
    'rawi' => InstructionRawImage
  }

  def process_line(line, program, line_index)
    line.strip!

    if line[0] == '-'
      # just a comment
      return true
    end

    tokens = line.split

    if tokens.length == 0
      return false
    end

    tokens.each_index do |i|
      tokens[i].chomp!(',')
    end

    match = tokens[0] =~ /^([A-Za-z_][A-Za-z0-9_]*:)$/
      if !match.nil?
        if tokens.length != 1
          return false
        end

        label_name = tokens[0][0..-2]
        if program.labels[label_name].nil?
          label = Label.new
          label.address = program.address
          program.labels[label_name] = label
          program.label_lines.add(line_index)
          return true
        else
          return false
        end
      end

    type = INSTRUCTION_TYPES[tokens[0]]
    if type.nil?
      return false
    end

    instruction = type.new
    instruction.line = line_index
    if !instruction.parse(tokens, program)
      return false
    end

    if !instruction.parse_line(line, program)
      return false
    end

    instruction.address = program.address
    program.address += instruction.length
    program.instructions.push(instruction)

    true
  end
end

if ARGV.size < 2
  puts('Usage: ruby cosmo.rb <asm_file> <output_binary> [-(m)if or -(h)ex]')
  exit 1
end

input_file = ARGV[0]
output_file = ARGV[1]
is_mif = ARGV.size > 2 && ARGV[2] == '-m'
is_hex = ARGV.size > 2 && ARGV[2] == '-h'

begin
  source = File.open(input_file, 'r')
rescue Exception => exception
  puts(exception)
  exit 1
end

program = Program.new
dispatch = InstructionDispatch.new
has_error = false

while line = source.gets
  result = dispatch.process_line(line, program, source.lineno)
  if !result
    puts("Syntax error on line #{source.lineno}: #{line}")
    has_error = true
  end
end

source.close

if has_error
  exit 1
end

program.instructions.each do |i|
  result = i.second_pass(program)
  if !result
    puts("Label does not exist on line #{i.line}")
    has_error = true
  end
end

if has_error
  exit 1
end

if !is_mif && !is_hex
  File.open(output_file, 'wb') do |file|
    program.instructions.each do |i|
      file.write(i.packed)
    end
  end
else
  if is_mif
    File.open(output_file, 'w') do |file|
      file.puts('DEPTH = 512;', 'WIDTH = 16;', 'ADDRESS_RADIX = HEX;',
                'DATA_RADIX = BIN;', 'CONTENT', 'BEGIN', '')

      program.instructions.each do |i|
        file.printf('%03X :', i.address)
        i.packed.unpack('S>*').each do |w|
          file.printf(' %016B', w)
        end
        file.printf("\n");
      end

      file.puts('', 'END;')
    end
  elsif is_hex
    File.open(output_file, 'w') do |file|
      program.instructions.each do |i|
        i.packed.unpack('S>*').each do |w|
          file.printf("%04X\n", w)
        end
      end
    end
  end
end

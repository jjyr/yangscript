require './lexer'
require './parser'
require './emitter'
require 'stringio'

module Yang
end

require 'pry-nav'
#test
source = open("./design.yang", "r").read.each_line.to_a
lexer = Yang::Lexer.new(source, trace_scan: false)
syntax_tree = Yang::Parser.new.parse(lexer)
output = StringIO.new
Yang::Emitter.new(output).emit(syntax_tree)
puts output.string

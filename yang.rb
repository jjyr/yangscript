require './lexer'
require './parser'
require './analyzer'
require './emitter'
require 'stringio'

module Yang
end

require 'pry-nav'
#test
source = open("./design.yang", "r").read.each_line.to_a
lexer = Yang::Lexer.new(source, trace_scan: false)
syntax_tree = Yang::Parser.new.parse(lexer)
analyzer = Yang::Analyzer.new
analyzer.analyze(syntax_tree)
p analyzer.symbol_table.keys
output = StringIO.new
#Yang::Emitter.new(output).emit(syntax_tree)
puts output.string

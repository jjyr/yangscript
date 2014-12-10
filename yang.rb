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
analyzer = Yang::Analyzer.new syntax_tree
analyzer.analyze
emitter = Yang::Emitter.new(syntax_tree, analyzer)
emitter.output = StringIO.new
emitter.emit
puts emitter.output.string

require './lexer'
require './parser'

module Yang
end

require 'pry-nav'
#test
source = open("./design.yang", "r").read.each_line.to_a
lexer = Yang::Lexer.new(source, trace_scan: false)
#nil while lexer.get_token.first != :endfile
Yang::Utils.print_tree Yang::Parser.new.parse(lexer)

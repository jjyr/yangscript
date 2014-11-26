require './lexer'
require './parser'

module Yang
end

require 'pry-nav'
#test
source = open("./design.yang", "r").read.each_line.to_a
lexer = Yang::Lexer.new(source, trace_scan: true)
#nil while lexer.next_token.first != :endfile
Yang::Utils.print_tree Yang::Parser.new.parse(lexer)

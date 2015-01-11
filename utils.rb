require './common'

module Yang
	module Utils
		class << self

			def print_token token, token_str
				if RESERVED_WORDS.values.include? token
					puts "reserved word: #{token_str}"
				else
					case token
					when :assign
						puts ":="
					when :lt
						puts "<"
					when :gt
						puts ">"
					when :eq
						puts "="
					when :lparen
						puts "("
					when :rparen
						puts ")"
					when :lbrace
						puts "{"
					when :rbrace
						puts "}"
					when :comma
						puts ","
					when :semi
						puts ";"
					when :newline
						puts "\\n"
					when :endfile
						puts "EOF"
					when :num
						puts token_str
					when :id
						puts "ID, name= #{token_str}"
					when :define_var
						puts ":="
					when :plus
						puts "+"
					when :dash
						puts "-"
					when :star
						puts "*"
					when :slash
						puts "/"
					when :error
						puts "ERROR: #{token_str}"
					else
						puts "Unknown token: #{token} value: #{token_str}"
					end
				end
			end

			def print_node tree, indent
				print_space indent
				if tree.is_a? StmtNode
					case tree.stmt
					when :def_var
						puts "def variable: #{tree.attrs[:name]}"
					when :def_func
						puts "def function: #{tree.attrs[:name]}, arity: #{tree.attrs[:arity]}"
					else
						puts tree.stmt.to_s
					end
				elsif ExpNode === tree
					case tree.exp
					when :op
						print "op: "
						print_token(tree.attrs[:op], '')
					when :literal_num
						puts "num: #{tree.attrs[:val]}"
					when :literal_bool
							puts "bool: #{tree.attrs[:val]}"
					when :id
						puts "id: #{tree.attrs[:name]}"
					when :call
						puts "fun_call: "
						print_space(indent + 2)
						print "function: "
						print_node tree.attrs[:object], indent
						p tree
					when :access
						print_node tree.attrs[:object], indent
						print_space(indent + 2)
						puts ".#{tree.attrs[:attribute]}"
					else
						puts "Unknown ExpNode kind: #{tree.inspect}"
					end
				else
					puts "Unknown Node kind: #{tree.inspect}"
				end
			end

			def print_space indentno
				print(" " * indentno)
			end

			def print_tree tree
				indentno = 2
				indent = ->{indentno += 2}
				unindent = ->{indentno -= 2}
				tree_printer = ->(tree){
					i = nil
					indent[]
					while tree
						print_node tree, indentno
						tree.children.each{|c| tree_printer[c]}
						tree = tree.sibling
					end
					unindent[]
				}
				tree_printer.call tree
			end

		end
	end
end

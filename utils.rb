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

			def print_tree tree
				indentno = 2
				indent = ->{indentno += 2}
				unindent = ->{indentno -= 2}
				print_space = ->{ print(" " * indentno) }
				print_node = ->(tree){
					i = nil
					indent[]
					while tree
						print_space[]
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
							when :func_call
								puts "func_call: #{tree.attrs[:name]}"
							else
								puts "Unknown ExpNode kind: #{tree.inspect}"
							end
						else
							puts "Unknown Node kind: #{tree.inspect}"
						end
						tree.children.each{|c| print_node[c]}
						tree = tree.sibling
					end
					unindent[]
				}
				print_node.call tree
			end

		end
	end
end

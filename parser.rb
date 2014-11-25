module Yang
  class TreeNode
    attr_accessor :children, :sibling, :line_no, :attrs

    def initialize
      @children = []
      @attrs = {}
    end
  end

  class StmtNode < TreeNode
    attr_accessor :stmt
  end

  class ExpNode < TreeNode
    attr_accessor :exp
  end

  module ParserHelper
    def stmt_node kind
      node = StmtNode.new
      node.stmt = kind
      node.line_no = @lexer.line_no
      node
    end

    def exp_node kind
      node = ExpNode.new
      node.exp = kind
      node.line_no = @lexer.line_no
      node
    end
  end

  class Parser

    include ParserHelper

    attr_reader :token, :token_str

    def parse lexer
      @lexer = lexer
      @token_buffer = []
      next_token
      t = TreeNode.new
      t = stmt_sequence
      if token != :endfile
        puts "Code ends before file"
      end
      t
    end

    def match expected
      if token == expected
        next_token
      else
        syntax_error
      end
    end

    def is_stmt_sequence_end
      token == :endfile || token == :semi
    end

    def stmt_sequence
      match token while token == :newline
      t = statement
      pt = t
      while !is_stmt_sequence_end
        match token while token == :newline
        break if is_stmt_sequence_end
        qt = statement
        if qt
          if t.nil?
            t = pt = qt
          else
            pt.sibling = qt
            pt = qt
          end
        end
      end
      t
    end

    def statement
      case token
      when :if
        if_stmt
      when :while
        while_stmt
      when :for
        for_stmt
      when :break
        break_stmt
      when :return
        return_stmt
      when :fun
        def_func_stmt
      when :print
        print_stmt
      else
        exp
      end
    end

    def if_stmt
      t = stmt_node :if
      match :if
      match :lparen
      t.children[0] = exp
      match :rparen
      match :lbrace
      t.children[1] = stmt_sequence
      match :rbrace
      if token == :else
        match :else
        match :lbrace
        t.children[2] = stmt_sequence if @token != :rbrace
        match :rbrace
      end
      t
    end

    def while_stmt
      t = stmt_node :while
      match :while
      match :lparen
      t.children[0] = exp
      match :rparen
      match :lbrace
      t.children[1] = stmt_sequence if @token != :rbrace
      match :rbrace
      t
    end

    def for_stmt
      t = stmt_node :for
      match :for
      match :lparen
      t.children[0] = exp
      match :semi
      t.children[1] = exp
      match :semi
      t.children[2] = exp
      match :rparen
      match :lbrace
      t.children[3] = stmt_sequence if @token != :rbrace
      match :rbrace
      t
    end

    def break_stmt
      t = stmt_node :break
      match :break
      t
    end

    def return_stmt
      t = stmt_node :return
      match :return
      t
    end

    def parse_id
      t = exp_node :id
      t.attrs[:name] = token_str
      match :id
      case token
      when :dot
        match :dot
        t.attrs[:key_id] = parse_id
      end
      return t
    end

    def parse_assignment first_id
      id_list = [first_id]
      while token == :comma
        match :comma
        id_list << parse_id
      end
      match :assign
      right_values = parse_exp_list
      if id_list.size == 1
        t = exp_node :assign
        t.attrs[:id] = first_id
        t.attrs[:values] = right_values
        t
      else
        t = exp_node :multiple_assign
        t.attrs[:id_list] = id_list
        t.attrs[:values] = right_values
        t
      end
    end

    def def_func_stmt
      t = stmt_node :def_func
      match :fun
      if token == :id
        t.attrs[:name] = @token_str
      end
      match :id
      t.attrs[:params] = def_func_parameters
      t.attrs[:arity] = t.attrs[:params].size
      match :lbrace
      if token != :rbrace
        t.children[0] = stmt_sequence
      end
      match :rbrace
      t
    end

    def parse_function_param_list
      params = []
      match :lparen
      while (token != :rparen)
        match :comma if params.size != 0
        params << token_str
        match :id
      end
      match :rparen
      params
    end

    def parse_function
      t = exp_node :literal
      t.attrs[:literal_type] = :fun
      match :fun
      t.attrs[:params] = parse_function_param_list
      match :dash
      match :gt
      t.children[0] = stmt_sequence
      match :semi
    end

    def parse_array
      t = exp_node :literal
      t.attrs[:literal_type] = :array
      match :lbracket
      t.attrs[:val_list] = parse_exp_list
      match :rbracket
    end

    def print_stmt
      t = stmt_node :print
      match :print
      t.children[0] = exp
      t
    end

    def exp
      t = simple_exp
      if token == :lt || token == :gt || token == :eq
        np = exp_node :op
        np.children[0] = t
        np.attrs[:op] = token
        t = np
        match token
        t.children[1] = simple_exp
      end
      t
    end

    def simple_exp
      t = factor
      while @token == :plus || @token == :dash
        np = exp_node :op
        np.children[0] = t
        np.attrs[:op] = @token
        t = np
        match @token
        t.children[1] = factor
      end
      t
    end

    def parse_exp_list
      list = [exp]
      while token == :comma
        match :comma
        list << exp
      end
      list
    end

    def parse_parameter_list
      parse_exp_list
    end

    def parse_func_call func_exp
      t = exp_node :func_call
      match :lparen
      t.attrs[:parameter_list] = parse_parameter_list
      match :rparen
      t.children[0] = func_exp
      t
    end

    def factor
      t = nil
      case token
      when :nil
        t = exp_node :literal
        t.attrs[:literal_type] = :nil
        t.attrs[:val] = :nil
        match :nil
      when :fun
        parse_function
      when :num
        t = exp_node :literal
        t.attrs[:literal_type] = :num
        t.attrs[:val] = token_str.to_i
        match :num
      when :true, :false
        t = exp_node :literal_bool
        t.attrs[:val] = token_str
        match token
      when :lbracket
        parse_array
      when :id
        t = nil
        match :id
        if token == :comma || token == :assign
          t = parse_assignment token_str
        elsif token == :lparen
          t = func_call token_str
        else
          t = exp_node :id
          t.attrs[:name] = token_str
        end
        t
      when :lparen
        match :lparen
        t = exp
        match :rparen
      else
        syntax_error
        next_token
      end

      if token == :lparen
        t = parse_func_call t
      end

      t
    end

    def back_token
      @token_buffer.push [@token, @token_str]
    end

    def next_token
      if @token_buffer.empty?
        @lexer.next_token
        @token, @token_str = @lexer.token, @lexer.token_str
      else
        @token, @token_str = @token_buffer.pop
      end
    end

    def syntax_error
      raise "syntaxError, unexpected token: #{@token} line: #{@lexer.line_no}"
    end
  end
end

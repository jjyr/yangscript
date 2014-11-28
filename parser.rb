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

  BINARY_OP_PRIOR = {
    or: 1,
    and: 2,
    lt: 3,
    lte: 3,
    gt: 3,
    gte: 3,
    eq: 3,
    plus: 4,
    dash: 4,
    star: 5,
    slash: 5,
    mod: 5
  }

  UNARY_OP = [:plus, :dash]

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

    def get_op_prior op
      BINARY_OP_PRIOR[op]
    end

    def is_unary_op op
      UNARY_OP.include? op
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
        parse_assignment_or_exp
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

    def parse_assignment_or_exp
      id_list = [exp]
      while token == :comma
        match :comma
        id_list << suffixed_exp
      end

      if token == :assign
        parse_assignment id_list
      elsif id_list.size == 1
        id_list[0]
      else
        syntax_error
      end
    end

    def parse_assignment id_list
      match :assign
      right_values = parse_exp_list
      if id_list.size == 1
        t = exp_node :assign
        t.attrs[:id] = id_list[0]
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

    def parse_function_call fun_exp
      t = exp_node :fun_call
      match :lparen
      t.attrs[:parameter_list] = parse_parameter_list
      match :rparen
      t.children[0] = fun_exp
      t
    end


    def parse_index_access obj_exp
      t = exp_node :index_access
      match :lbracket
      t.attrs[:object] = obj_exp
      t.attrs[:params] = parse_parameter_list
      match :rbracket
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
      t.attrs[:type] = :fun
      match :fun
      t.attrs[:params] = parse_function_param_list
      match :dash
      match :gt
      t.children[0] = stmt_sequence
      match :semi
    end

    def parse_hash
      t = exp_node :literal
      t.attrs[:type] = :hash
      match :lbrace
      hash_value = {}
      while token != :rbrace
        key = token_str
        match :id
        match :colon
        hash_value[key] = exp
        match :comma if token != :rbrace
      end
      match :rbrace
      t.attrs[:val] = hash_value
      t
    end

    def parse_array
      t = exp_node :literal
      t.attrs[:type] = :array
      match :lbracket
      t.attrs[:val] = parse_exp_list
      match :rbracket
      t
    end

    def print_stmt
      t = stmt_node :print
      match :print
      t.children[0] = exp
      t
    end

    def exp
      subexp(0)
    end

    def subexp limit
      if is_unary_op(token)
        match token
        t = exp_node :op
        t.attrs[:op] = token
        t.children[0] = primary_exp
        return t
      end

      t = suffixed_exp
      op_prior = get_op_prior token
      while op_prior && op_prior > limit
        op_node = exp_node :op
        op_node.attrs[:op] = token
        match token
        op_node.children[0] = t
        op_node.children[1] = subexp(op_prior)
        t = op_node
        op_prior = get_op_prior token
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

    def parse_attribute_access obj_exp
      t = exp_node :access
      match :dot
      t.attrs[:object] = obj_exp
      t.attrs[:attribute] = token_str
      match :id
      t
    end

    def primary_exp
      case token
      when :nil
        t = exp_node :literal
        t.attrs[:type] = :nil
        t.attrs[:val] = :nil
        match :nil
        t
      when :fun
        parse_function
      when :num
        t = exp_node :literal
        t.attrs[:type] = :num
        t.attrs[:val] = token_str.to_i
        match :num
        t
      when :true, :false
        t = exp_node :literal
        t.attrs[:type] = :bool
        t.attrs[:val] = token_str
        match token
        t
      when :string
        t = exp_node :literal
        t.attrs[:type] = :string
        t.attrs[:val] = token_str
        match :string
        t
      when :id
        t = exp_node :id
        t.attrs[:name] = token_str
        match :id
        t
      when :lparen
        match :lparen
        t = exp
        match :rparen
        t
      when :lbracket
        parse_array
      when :lbrace
        parse_hash
      else
        syntax_error
      end
    end

    def suffixed_exp
      t = primary_exp

      loop do
        if token == :dot
          t = parse_attribute_access t
        elsif token == :lparen
          t = parse_function_call t
        elsif token == :lbracket
          t = parse_index_access t
        else
          break
        end
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

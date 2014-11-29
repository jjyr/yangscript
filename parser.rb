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

    STOP_TOKENS = [:semi].freeze

    def stmt_sequence stop_tokens=STOP_TOKENS
      trim_empty_lines
      t = if stop_tokens.include? token
            empty_statement
          else
            statement
          end
      trim_empty_lines
      pt = t
      while !(token == :endfile) && !stop_tokens.include?(token)
        qt = statement
        trim_empty_lines
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

    def trim_empty_lines
      match token while token == :newline
    end

    def empty_statement
      stmt_node :nothing
    end

    def statement
      case token
      when :while
        while_stmt
      when :for
        for_stmt
      when :break
        break_stmt
      when :return
        return_stmt
      when :print
        print_stmt
      when :class
        class_stmt
      else
        parse_assignment_or_exp
      end
    end

    def while_stmt
      t = stmt_node :while
      match :while
      match :lparen
      t.children[0] = exp
      match :rparen
      match :lbrace
      t.children[1] = stmt_sequence
      match :rbrace
      t
    end

    def for_stmt
      t = stmt_node :for
      match :for
      id_list = [token_str]
      match :id
      while token == :comma
        match :comma
        id_list << token_str
        match :id
      end
      match :in
      t.attrs[:id_list] = id_list
      t.attrs[:iter_exp] = suffixed_exp
      t.children[0] = stmt_sequence
      match :semi
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

    def class_stmt
      t = stmt_node :class
      match :class
      t.attrs[:name] = token_str
      t.children[0] = stmt_sequence
      match :semi
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
      elsif token == :or_assign
        parse_or_assign id_list[0]
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
        t = stmt_node :assign
        t.attrs[:id] = id_list[0]
        t.attrs[:values] = right_values
        t
      else
        t = stmt_node :multiple_assign
        t.attrs[:id_list] = id_list
        t.attrs[:values] = right_values
        t
      end
    end

    def parse_or_assign var_id
      match :or_assign
      t = stmt_node :or_assign
      t.attrs[:id] = var_id
      t.attrs[:value] = exp
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
      match :fun
      t = nil
      if token == :id
        t = exp_node :define_function
        t.attrs[:name] = token_str
        match :id
      else
        t = exp_node :literal
        t.attrs[:type] = :fun
      end
      t.attrs[:params] = parse_function_param_list
      match :dash
      match :gt
      t.children[0] = stmt_sequence
      match :semi
      t
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
      list = []
      list << exp if token != :rparen
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


    IF_STOP_TOKENS = [:elsif, :else, :semi].freeze
    def parse_if_exp
      t = exp_node :if
      match :if
      branch = {}
      branch[:condition] = exp
      branch[:body] = stmt_sequence(IF_STOP_TOKENS)
      branches = [branch]
      while token == :elsif
        match :elsif
        branch = {}
        branch[:condition] =  exp
        branch[:body] = stmt_sequence(IF_STOP_TOKENS)
        branches << branch
      end
      if token == :else
        match :else
        branch = {condition: :else}
        branch[:body] = stmt_sequence(IF_STOP_TOKENS)
        branches << branch
      end
      match :semi
      t.attrs[:branches] = branches
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
      when :if
        parse_if_exp
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
      raise "syntaxError, unexpected token: #{token} value: #{token_str} line: #{@lexer.line_no}"
    end
  end
end

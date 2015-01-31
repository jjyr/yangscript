module Yang
  class TreeNode
    attr_accessor :node_type, :kind, :children, :sibling, :line_no, :attrs, :outer, :symbol_table

    def initialize
      @children = []
      @attrs = {}
      @symbol_table = {}
    end
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

  UNARY_OP = [:plus, :dash, :not]

  module ParserHelper
    def stmt_node kind
      node = TreeNode.new
      node.kind = kind
      node.node_type = :statement
      @lexer && node.line_no = @lexer.line_no
      node
    end

    def exp_node kind
      node = TreeNode.new
      node.kind = kind
      node.node_type = :exp
      @lexer && node.line_no = @lexer.line_no
      node
    end

    def nil_node
      t = exp_node :literal
      t.attrs[:type] = :nil
      t
    end

    def get_op_prior op
      BINARY_OP_PRIOR[op]
    end

    def is_unary_op op
      UNARY_OP.include? op
    end
  end

  class SafeParser

    def initialize parser
      @parser = parser
      @parse_error = false
      @matched = []
    end

    attr_reader :parse_error

    def match expected
      return if @parse_error
      if expected != @parser.token
        @parse_error = true
        return
      end
      @matched << @parser.lexer.token_info
      @parser.match(expected)
    end

    def resume
      @parser.lexer.back_token
      limit = @matched.count - 1
      @matched.reverse.each_with_index do |t, i|
        @parser.lexer.set_current t
        @parser.lexer.back_token if i < limit
      end
    end
  end

  class Parser

    include ParserHelper

    attr_reader :token, :token_str, :lexer

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

    def match expected, read_token = true
      if token == expected
        read_token and next_token
      else
        syntax_error
      end
    end


    def match_one *tokens
      if tokens.include? token
        match token
      else
        syntax_error
      end
    end

    STOP_TOKENS = [:semi].freeze

    def stmt_sequence stop_tokens=STOP_TOKENS
      trim_empty_lines
      t = if stop_tokens.include? token
            nil_node
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
      var_list = [token_str]
      match :id
      while token == :comma
        match :comma
        var_list << token_str
        match :id
      end
      match :in
      t.attrs[:var_list] = var_list
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

    def parse_class
      t = exp_node :class
      match :class
      t.attrs[:prototype] = parse_object
      t
    end

    def parse_assignment_or_exp
      left_list = [exp]
      while token == :comma
        match :comma
        left_list << suffixed_exp
      end

      if token == :assign
        parse_assignment left_list
      elsif token == :or_assign
        parse_or_assign left_list[0]
      elsif left_list.size == 1
        left_list[0]
      else
        syntax_error
      end
    end

    def parse_assignment left_list
      match :assign
      if left_list.size == 1
        t = stmt_node :assign
        value = exp
        while token == :assign
          match :assign
          left_list << value
          value = nil
        end
        raise_error("right side more than 1 value") if token == :comma
        t.attrs[:value] = value
        t.attrs[:left_list] = left_list
        t
      else
        t = stmt_node :multiple_assign
        t.attrs[:left_list] = left_list
        t.attrs[:values] = parse_exp_list
        t
      end
    end

    def parse_or_assign var_id
      match :or_assign
      t = stmt_node :or_assign
      t.attrs[:left] = var_id
      t.attrs[:value] = exp
      t
    end

    def parse_function_call fun_exp
      t = exp_node :call
      match :lparen
      t.attrs[:params] = parse_parameter_list
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

    class FunctionParam
      attr_accessor :type
      def initialize
      end
    end

    def try_parse_function_param_list
      params = []
      sp = SafeParser.new self

      sp.match :lparen
      while (token != :rparen) && !sp.parse_error
        if params.size != 0
          sp.match(:comma)
        end
        param = {type: :normal}
        if token == :star
          match :star
          param[:type] = :compress
        end
        param[:name] =  token_str
        sp.match(:id)
        if token == :assign
          match :assign
          if param[:type] == :normal
            param[:type] = :default
          else
            syntax_error
          end
          param[:default_value] = exp #should use sp
        end
        params << param
      end
      sp.match(:rparen)

      [params, sp]
    end

    def parse_function_param_list
      params, sp = try_parse_function_param_list
      sp.parse_error and syntax_error
      params
    end

    def define_function_stmt
      match :def
      t = nil
      t = stmt_node :define_function
      t.attrs[:name] = token_str
      match :id
      t.attrs[:params] = parse_function_param_list
      match :arrow
      t.children[0] = stmt_sequence
      match :semi
      t
    end

    def match_pair start_t, end_t
      match start_t
      trim_empty_lines
      while token != end_t
        yield
        trim_empty_lines
      end
      match end_t
    end

    def parse_object
      t = exp_node :literal
      t.attrs[:type] = :object
      value = {}
      match_pair(:lbrace, :rbrace) do
        key = token_str
        match_one :id, *RESERVED_WORDS.values
        match :colon
        value[key] = exp
        match_one(:comma, :newline) if token != :rbrace
      end
      t.attrs[:val] = value
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

    def parse_new
      t = exp_node :new
      match :new
      t.attrs[:class_exp] = exp
      t
    end

    def keep_embed_state &block
      @lexer.current_minor_lexer.keep_embed_state &block
    end

    def parse_external
      t = exp_node :external
      @lexer.use_lexer_in_context :external_lexer do
        keep_embed_state do
          match :backquote
          contents = []
          while token != :backquote
            case token
            when :external_fragment
              fragment = exp_node :external_fragment
              fragment.attrs[:content] = token_str
              contents << fragment
              match :external_fragment
            else
              match :at
              match :lbrace
              contents << exp
              match :rbrace
            end
          end
          t.attrs[:contents] = contents
          # skip next_token, to prevent external lexer match
          match :backquote, false
        end
      end
      next_token
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
        t = exp_node :operator
        t.attrs[:operator] = token
        match token
        t.children[0] = suffixed_exp
      else
        t = suffixed_exp
      end
      op_prior = get_op_prior token
      while op_prior && op_prior > limit
        op_node = exp_node :operator
        op_node.attrs[:operator] = token
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

    def parse_delegate obj_exp
      t = exp_node :delegate
      match :at
      t.attrs[:object] = obj_exp
      t.attrs[:target] = primary_exp
      keys = []
      if token == :lbrace
        match_pair(:lbrace, :rbrace) do
          key = token_str
          match :id
          keys << key
          match_one(:comma, :newline) if token != :rbrace
        end
        raise "delegate keys can not be empty" if keys.empty?
      end
      t.attrs[:keys] = keys
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
      when :self
        t = exp_node :self
        match :self
        t
      when :nil
        t = exp_node :literal
        t.attrs[:type] = :nil
        t.attrs[:val] = :nil
        match :nil
        t
      when :id
        t = exp_node :id
        t.attrs[:name] = token_str
        match :id
        t
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
      when :regexp
        t = exp_node :literal
        t.attrs[:type] = :regexp
        t.attrs[:val] = token_str
        match :regexp
        t
      when :lbracket
        parse_array
      when :lbrace
        parse_object
      when :class
        parse_class
      when :new
        parse_new
      when :if
        parse_if_exp
      when :backquote
        parse_external
      when :lparen
        try_parse_lambda_or_in_paren_exp
      else
        syntax_error
      end
    end

    def parse_lambda params
      match :arrow
      t = nil
      t = exp_node :literal
      t.attrs[:type] = :lambda
      t.attrs[:params] = params
      t.children[0] = stmt_sequence
      match :semi
      t
    end

    def try_parse_lambda_or_in_paren_exp
      t = nil
      params, sp = try_parse_function_param_list
      if !sp.parse_error && token == :arrow
        t = parse_lambda params
      else
        sp.resume
        match :lparen
        t = exp
        match :rparen
        t
      end
      t
    end

    def suffixed_exp
      t = primary_exp

      loop do
        if token == :dot
          t = parse_attribute_access t
        elsif token == :at
          t = parse_delegate t
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

    def token
      @lexer.token
    end

    def token_str
      @lexer.token_str
    end

    def next_token
      @lexer.next_token
    end

    def syntax_error
      raise "syntaxError, unexpected token: #{token} value: #{token_str} line: #{@lexer.line_no}"
    end
  end
end

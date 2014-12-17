module Yang
  class Analyzer
    include ParserHelper

    attr_reader :global_node

    def initialize tree
      @global_node = TreeNode.new
      @global_node.symbol_table = {}
      @tree = tree
    end

    def analyze
      build_symbol_table @tree
    end

    private
    def build_symbol_table node, outer = global_node
      loop do
        node.outer = outer
        build_from_node(node)
        node = node.sibling
        node.nil? and break
      end
    end

    def search_function_params node, key
      if node.kind == :function || node.attrs[:type] == :fun
        node.attrs[:params].include? key
      else
        false
      end
    end

    def search_key context, key
      if context.symbol_table.has_key?(key)
        context
      elsif context.outer
        search_key(context.outer, key)
      else
        nil
      end
    end

    def insert_table key, context, node
      if new_context = search_key(context, key)
        new_context.symbol_table[key].include? node or new_context.symbol_table[key] << node
      elsif search_function_params(context, key)
        params_symbol_table = context.attrs[:params_symbol_table] ||= {}
        params_symbol_table[key] ||= []
        params_symbol_table[key].include? node or params_symbol_table[key] << node
      else
        context.symbol_table[key] = [node]
      end
    end

    def insert node, context
      name = node.attrs[:name]
      insert_table name, context, node
    end

    def build_from_node node
      case node.kind
      when :assign
        node.attrs[:id].kind == :id and insert node.attrs[:id], node.outer
        build_from_node node.attrs[:value]
      when :multiple_assign
        node.attrs[:id_list].each do |id_node|
          id_node.kind == :id and insert id_node, node.outer
        end
        node.attrs[:values].each do |value|
          build_from_node value
        end
      when :for
        node.attrs[:var_list].each do |var|
          insert_table var, node.outer, node
        end
      when :literal
        case node.attrs[:type]
        when :fun
          trans_function node
          build_inner_node node
        end
      when :define_function
        if node.outer.kind != :class
          analyze_error "named function can only defined in class context", node
        end
        trans_function node
        node.attrs[:name] and insert_table node.attrs[:name], node.outer, node
        build_inner_node node
      when :class
        insert_table node.attrs[:name], node.outer, node
        build_inner_node node
      end
    end

    def sequence_to_array node
      result = []
      while node.sibling
        result << node
        node = node.sibling
      end
      result << node
      result
    end

    def array_to_sequence nodes
      first_node = node = nodes.shift
      while node.sibling = nodes.shift
        node = node.sibling
      end
      first_node
    end

    def trans_function fun_node
      fun_node.children[0] = trans_stmt_seq_return fun_node.children[0]
    end

    def trans_stmt_seq_return stmt_seq
      body = sequence_to_array stmt_seq
      stmt = body.last
      return_node = stmt_node :return
      return_node.line_no = stmt.line_no
      if stmt.node_type == :statement
        if stmt.kind == :if
          branches = stmt.attrs[:branches]
          btanches.each do |branch|
            branch[:body] = trans_stmt_seq_return branch[:body]
          end
          if branches.last.attrs[:condition] != :else
            return_node.attrs[:val] = nil_node
            body << return_node
          end
        elsif stmt.kind != :return
          return_node.attrs[:val] = nil_node
          body << return_node
        end
      else
        return_node.attrs[:val] = stmt
        body[-1] = return_node
      end
      array_to_sequence body
    end

    def build_inner_node node
      if [:class, :define_function].include?(node.kind) || (node.kind == :literal && node.attrs[:type] == :fun)
        inner = node.children[0]
        build_symbol_table inner, node
      else
        analyze_error "cannot detect node kind #{node.kind}", node
      end
    end

    def analyze_error msg, node
      raise "#{node.line_no} line: #{msg}"
    end
  end
end

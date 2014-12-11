module Yang
  class Analyzer
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

    def search_key context, key
      if context.symbol_table.has_key? key
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
      else
        context.symbol_table[key] = [node]
      end
    end

    def insert node, context
      name = node.attrs[:name]
      insert_table name, context, node
    end

    def insert_multiple nodes, context
      nodes.each do |id_node|
        id_node.kind == :id and insert id_node, context
      end
    end

    def build_from_node node
      case node.kind
      when :assign
        node.attrs[:id].kind == :id and insert node.attrs[:id], node.outer
      when :multiple_assign
        insert_multiple node.attrs[:id_list], node.outer
      when :function
        node.attrs[:name] and insert_table node.attrs[:name], node.outer, node
        build_inner_node node
      when :class
        insert_table node.attrs[:name], node.outer, node
        build_inner_node node
      end
    end

    # def init_function_symbol_table node
    #   table = node.symbol_table
    #   node.attrs[:params].each do |name|
    #     if table.has_key? name
    #       analyzer_error "duplicate parameter name: #{name}", node
    #     else
    #       table[name] = [node]
    #     end
    #   end
    # end

    def build_inner_node node
      case node.kind
      when :function
        inner = node.children[0]
        #init_function_symbol_table node
        build_symbol_table inner, node
      when :class
        inner = node.children[0]
        build_symbol_table inner, node
      else
        raise "cannot detect inner node type: #{node.kind}"
      end
    end

    def analyzer_error msg, node
      raise "#{node.line_no} line: #{msg}"
    end
  end
end

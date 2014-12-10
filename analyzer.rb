module Yang
  class Analyzer
    attr_reader :symbol_table

    def initialize tree
      @symbol_table = {}
      @tree = tree
    end

    def analyze
      build_symbol_table @tree
    end

    private
    def build_symbol_table node, table = @symbol_table, outer_node = nil
      loop do
        outer_node and node.outer_node = outer_node
        build_from_node(node, table)
        node = node.sibling
        node.nil? and break
      end
    end

    def insert_table key, table, node
      if table.has_key? key
        table[key].include? node or table[key] << node
      else
        table[key] = [node]
      end
    end

    def insert node, table = @symbol_table
      name = node.attrs[:name]
      insert_table name, table, node
    end

    def insert_multiple nodes, table = @symbol_table
      nodes.each do |id_node|
        id_node.kind == :id and insert id_node, table
      end
    end

    def build_from_node node, table = @symbol_table
      case node.kind
      when :assign
        node.attrs[:id].kind == :id and insert node.attrs[:id], table
      when :multiple_assign
        insert_multiple node.attrs[:id_list], table
      when :function
        node.attrs[:name] and insert_table node.attrs[:name], table, node
        build_inner_node node
      when :class
        insert_table node.attrs[:name], table, node
        build_inner_node node
      end
    end

    def init_function_symbol_table node
      table = node.symbol_table
      node.attrs[:params].each do |name|
        if table.has_key? name
          analyzer_error "duplicate parameter name: #{name}", node
        else
          table[name] = [node]
        end
      end
    end

    def build_inner_node node
      case node.kind
      when :function
        inner = node.children[0]
        init_function_symbol_table node
        build_symbol_table inner, node.symbol_table, node
      when :class
        inner = node.children[0]
        build_symbol_table inner, node.symbol_table, node
      else
        raise "cannot detect inner node type: #{node.kind}"
      end
    end

    def analyzer_error msg, node
      raise "#{node.line_no} line: #{msg}"
    end
  end
end

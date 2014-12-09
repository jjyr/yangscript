module Yang
  class Analyzer
    attr_reader :symbol_table

    def initialize
      @symbol_table = {}
    end

    def build_symbol_table tree
      loop do
        build_outer_symbol_table(tree)
        node = node.sibling
        node.nil? and break
      end
    end

    private
    def insert node
      name = node.attrs[:name]
      if @symbol_table.has_key? name
        @symbol_table[name].include? node or @symbol_table[name] << node
      else
        @symbol_table[name] = node
      end
    end

    def insert_multiple node
      node.attrs[:id_list].each do |name|
        if @symbol_table.has_key? name
          @symbol_table[name].include? node or @symbol_table[name] << node
        else
          @symbol_table[name] = node
        end
      end
    end

    def build_outer_symbol_table node
      case node.kind
      when :assign
        insert node
      when :multiple_assign
        insert_multiple node
      when :function, :class
        build_scope_symbol_table
      end
    end
  end
end

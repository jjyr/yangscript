module Yang
  class Emitter
    attr_accessor :output
    def initialize output
      @output = output
    end

    def write str
      @output.write str
    end

    def emit(tree)
      emit_seq tree
    end

    def emit_seq node
      loop do
        write emit_statement(node)
        node = node.sibling
        node.nil? and break
      end
    end

    def emit_statement node
      case node.kind
      when :while
        emit_while node
      when :for
        emit_for node
      when :break
        emit_break
      when :return
        emit_return node
      when :print
        emit_print node
      when :class
        emit_class node
      when :assign
        emit_assign node
      when :multiple_assign
        emit_multiple_assign node
      else
        emit_exp node
      end
    end

    def emit_exp node
      case node.kind
      when :literal
        emit_literal node
      when :id
        emit_id node
      when :access
        emit_access node
      when :operator
        emit_operator node
      when :fun_call
        emit_function_call node
      else
        raise "cannot detect exp kind: #{node.kind}"
      end
    end

    def emit_operator node
      case node.attrs[:operator]
      when :plus
        write "+"
      else
        raise "cannot detect operator: #{node.attrs[:operator]}"
      end
    end

    def emit_exp_list list
      limit = list.size - 1
      list.each_with_index do |param_node, i|
        emit_exp param_node
        write "," if i < limit
      end
    end

    def emit_function_call node
      emit_exp node.children[0]
      write "("
      emit_exp_list node.attrs[:params]
      write ")"
    end

    def emit_id node
      write node.attrs[:name]
    end

    def emit_access node
      # attribute path: a.b.c.d
      access_path = node.attrs[:attribute]
      obj_exp = node.attrs[:object]
      while obj_exp.kind == :access
        access_path.unshift "."
        access_path.unshift obj_exp.attrs[:attribute]
        obj_exp = obj_exp.attrs[:object]
      end
      emit_exp obj_exp
      write access_path
    end

    def emit_literal node
      case node.attrs[:type]
      when :num
        emit_num node
      when :fun
        emit_function node
      when :array
        emit_array node
      else
        raise "cannot detect literal type: #{node.attrs[:type]}"
      end
    end

    def emit_num node
      write node.attrs[:val].to_s
    end

    def emit_function node
      write "function("
      write node.attrs[:params].join(",")
      write "){"
      emit_seq node.children[0]
      write "}"
    end

    def emit_array node
      write "["
      emit_exp_list node.attrs[:val]
      write "]"
    end

    def emit_assign node
      write "var #{node.attrs[:id]} = "
      emit_exp node.attrs[:value]
    end

    def emit_multiple_assign node
      write "var"
      raise "not complete"
    end

    def emit_print
      write "console.log("
      emit_exp
      write ")"
    end
  end
end

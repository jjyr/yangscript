module Yang
  class Emitter
    attr_accessor :output

    def initialize syntax_tree, analizer
      @analizer = analizer
      @syntax_tree = syntax_tree
    end

    def write str
      @output.print str
    end

    def emit
      emit_variables_define @syntax_tree.outer
      emit_seq @syntax_tree
    end

    def emit_variables_define node
      vars = node.symbol_table.keys
      vars += node.attrs[:temp_vars] if node.attrs[:temp_vars]
      return if vars.empty?
      write "var "
      limit = vars.length - 1
      vars.each_with_index do |var, i|
        write var
        write "," if i < limit
      end
      write ";"
    end

    def emit_seq node, sep = ";\n", write_last=true
      loop do
        emit_statement(node)
        node = node.sibling
        node.nil? and break
        write sep
      end
      write sep if write_last
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
      when :define_function
        emit_define_function node
      when :nothing
        #just do nothing
      else
        emit_exp node
      end
    end

    def tmp_var context
      i = 0
      tmp = "t#{i}"
      context.attrs[:temp_vars] ||= []
      loop do
        if context.symbol_table.has_key?(tmp) || context.attrs[:temp_vars].include?(tmp)
          i += 1
          tmp = "t#{i}"
        else
          context.attrs[:temp_vars] << tmp
          return tmp
        end
      end
    end

    def emit_return node
      write "return "
      node.attrs[:val] and emit_exp node.attrs[:val]
    end

    def emit_for node
      iter_var = tmp_var node.outer
      i_var = tmp_var node.outer
      write iter_var
      write "="
      emit_exp node.attrs[:iter_exp]
      write "for("
      write i_var
      write "=0;"
      write i_var
      write "<"
      write iter_var
      write ".length;"
      write i_var
      write "++"
      write "){"
      node.attrs[:var_list].each_with_index do |var, i|
        write var
        write "="
        write iter_var
        write "["
        write i
        write "];"
      end
      emit_seq node.children[0]
      write "}"
    end

    def emit_if node
      branches = node.attrs[:branches]
      branches.each_with_index do |branch, i|
        if branch[:condition] == :else
          if i != branches.size - 1
            raise "'else' must be last branch of if statement"
          end
          break
        end
        emit_exp(branch[:condition])
        write "?"
        emit_seq(branch[:body], ",", false)
        write ":"
      end
      if (branch = branches[-1])[:condition] == :else
        emit_seq(branch[:body], ",", false)
      else
        write "null"
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
      when :index_access
        emit_index_access node
      when :if
        emit_if node
      else
        raise "cannot detect exp kind: #{node.kind}"
      end
    end

    def write_function_call fun, args = []
      limit = args.size - 1
      write fun
      write "("
      args.each_with_index do |arg, i|
        write arg
        write "," if i < limit
      end
      write ")"
    end

    def emit_define_function node
      var = node.attrs[:name]
      write var
      write "="
      emit_function node
      write_function_call "$define_function", [node.outer.attrs[:name], var]
    end

    def emit_get_attr obj, attr
      write "$obj_attr("
      emit_exp obj
      write ", '$"
      write attr
      write "')"
    end

    def emit_index_access node
      emit_get_attr node.attrs[:object], "[]"
      write("(")
      emit_exp_list node.attrs[:params]
      write(")")
    end

    def write_operator op
      case op
      when :plus
        write "+"
      else
        raise "cannot detect operator #{op}"
      end
    end

    def emit_operator node
      left = node.children[0]
      right = node.children[1]
      if right
        emit_exp left
        write_operator node.attrs[:operator]
        emit_exp right
      else
        write_operator node.attrs[:operator]
        emit_exp left
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
      write "."
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
      when :string
        emit_string node
      when :hash
        emit_hash node
      when :nil
        emit_nil node
      else
        raise "cannot detect literal type: #{node.attrs[:type]}"
      end
    end

    def emit_nil node
      write "null"
    end

    def emit_num node
      write node.attrs[:val].to_s
    end

    def emit_function node
      write "function("
      write node.attrs[:params].join(",")
      write "){"
      emit_variables_define node
      emit_seq node.children[0]
      write "}"
    end

    def emit_hash node
      write "{"
      node.attrs[:val].each do |k, v|
        write_string k
        write ":"
        emit_exp v
        write ","
      end
      write "}"
    end

    def write_string str
      write '"'
      write str
      write '"'
    end

    def emit_string node
      write_string node.attrs[:val]
    end

    def emit_array node
      write "["
      emit_exp_list node.attrs[:val]
      write "]"
    end

    def emit_id node
      write node.attrs[:name]
    end

    def emit_assign node
      emit_id node.attrs[:id]
      write " = "
      emit_exp node.attrs[:value]
    end

    def emit_multiple_assign node
      var_list = node.attrs[:id_list]
      node.attrs[:values].each_with_index do |exp_node, i|
        if var = var_list[i]
          write var.attrs[:name]
          write "="
        end
        emit_exp exp_node
        write ";" if var_list.size > i
      end
    end

    def emit_print
      write "console.log("
      emit_exp
      write ")"
    end
  end
end

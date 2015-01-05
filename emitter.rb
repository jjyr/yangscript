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
      emit_runtime
      emit_env do
        emit_variables_define @syntax_tree.outer
        emit_seq @syntax_tree
      end
    end

    def emit_runtime
      write open("./env/runtime.js").read
    end

    def emit_env
      write "(function($env){"
      write "var $_hash = $env._hash, $_bool = $env._bool, $new_class = $env.new_class, $defun = $env.defun, $get = $env.get_attribute, $set_ivar = $env.set_instance_var, $get_ivar = $env.get_instance_var;"
      yield
      write "})(yangscript)"
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
      when :defun
        emit_defun node
      when :assign
        emit_assign node
      when :multiple_assign
        emit_multiple_assign node
      when :or_assign
        emit_or_assign node
      when :define_function
        emit_define_function node
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
      write ";"
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
      if node.attrs[:var_list].size > 1
        node.attrs[:var_list].each_with_index do |var, i|
          write var
          write "="
          write iter_var
          write "["
          write i_var
          write "]["
          write i
          write "}];"
        end
      else
        var = node.attrs[:var_list][0]
        write var
        write "="
        write iter_var
        write "["
        write i_var
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
        write "$_bool("
        emit_exp(branch[:condition])
        write ")"
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
      when :new
        emit_new node
      when :external
        emit_external node
      else
        raise "cannot detect exp kind: #{node.kind}"
      end
    end

    def emit_external node
    end

    def emit_new node
      write "new "
      emit_exp node.attrs[:class_exp]
    end

    def emit_define_function node
      var = node.attrs[:name]
      write var
      write "="
      emit_function node
      write ";"
      write "$defun("
      write node.outer.attrs[:name]
      write ","
      write_string "$#{var}"
      write ","
      write var
      write ")"
    end

    def emit_get_attr obj, attr
      emit_exp obj
      write "['$"
      write attr
      write "']"
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
      when :or
        write "||"
      when :gt
        write ">"
      when :eq
        write "==="
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
      write_list(list){|node| emit_exp(node)}
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

    def emit_get_attribute obj_exp, key
      write "$get("
      if obj_exp.kind == :access
        emit_get_attribute obj_exp.attrs[:object], obj_exp.attrs[:attribute]
      else
        emit_exp obj_exp
      end
      write ","
      write_string "$#{key}"
      write ")"
    end

    def emit_instance_var_get obj, key
      write "$get_ivar("
      emit_exp obj
      write ","
      write_string "$#{key}"
      write ")"
    end

    def emit_access node
      key = node.attrs[:attribute]
      # start_with '_' means instance variable
      if key.start_with? "_"
        emit_instance_var_get node.attrs[:object], key
      else
        emit_get_attribute node.attrs[:object], key
      end
    end


    def emit_class node
      class_name = node.attrs[:name]
      write class_name
      write "="
      write "function(){"
      write "var "
      write class_name
      write " = $new_class("
      write_string class_name
      write ");"
      emit_seq node.children[0]
      write "return "
      write class_name
      write ";}()"
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
      when :bool
        emit_bool node
      when :nil
        emit_nil node
      else
        raise "cannot detect literal type: #{node.attrs[:type]}"
      end
    end

    def emit_bool node
      write node.attrs[:val]
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

    def write_list list
      limit = list.size - 1
      list.each_with_index do |elem, i|
        yield elem
        write "," if i < limit
      end
    end

    def emit_hash node
      write "$_hash({"
      node.attrs[:val].each do |k, v|
        write_string k
        write ":"
        emit_exp v
        write ","
      end
      write "},"
      write "["
      write_list(node.attrs[:val].keys){|str| write_string str}
      write "]"
      write ")"
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

    def emit_var_assign left, value
      emit_id left
      write "="
      emit_exp value
    end

    def emit_instance_var_set left, value
      write "$set_ivar("
      emit_exp left.attrs[:object]
      write ","
      write_string "$#{left.attrs[:attribute]}"
      write ","
      emit_exp value
      write ")"
    end

    def emit_left_assign left, value
      case left.kind
      when :id
        emit_var_assign left, value
      when :access
        emit_instance_var_set left, value
      else
        raise "cannot detect left value kind: #{left.kind}"
      end
    end

    def emit_assign node
      emit_left_assign node.attrs[:left], node.attrs[:value]
    end

    def emit_multiple_assign node
      var_list = node.attrs[:left_list]
      t_var = tmp_var node.outer
      write t_var
      write "="
      write "["
      values = node.attrs[:values]
      values.each_with_index do |exp_node, i|
        emit_exp exp_node
        write "," if values.size - 1 > i
      end
      write "];"
      var_list.each do |var|
        write var.attrs[:name]
        write "="
        write t_var
        write ".shift();"
      end
    end

    def emit_or_assign node
      emit_exp node.attrs[:left]
      write "||"
      emit_left_assign node.attrs[:left], node.attrs[:value]
    end

    def emit_print node
      write "console.log("
      emit_exp node.children[0]
      write ")"
    end
  end
end

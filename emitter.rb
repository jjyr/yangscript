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
      write "var $_hash = $env._hash, $_bool = $env._bool, $new_class = $env.new_class, $def = $env.def, $get = $env.get_attribute, $set_ivar = $env.set_instance_var, $get_ivar = $env.get_instance_var;"
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
      when :assign
        emit_assign node
      when :multiple_assign
        emit_multiple_assign node
      when :or_assign
        emit_or_assign node
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
      emit_exp node.attrs[:val] if node.attrs[:val]
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
      when :self
        emit_self node
      when :literal
        emit_literal node
      when :id
        emit_id node
      when :access
        emit_access node
      when :delegate
        emit_delegate node
      when :operator
        emit_operator node
      when :call
        emit_function_call node
      when :index_access
        emit_index_access node
      when :if
        emit_if node
      when :new
        emit_new node
      when :class
        emit_class node
      when :external
        emit_external node
      else
        raise "cannot detect exp kind: #{node.kind}"
      end
    end

    def emit_self node
      write "this"
    end

    def emit_external node
      node.attrs[:contents].each do |i|
        case i.kind
        when :external_fragment
          write i.attrs[:content]
        else
          emit_exp i
        end
      end
    end

    def emit_new node
      write "new "
      emit_exp node.attrs[:class_exp]
    end

    def emit_delegate node
      write "function(){"
      write "var obj="
      emit_exp node.attrs[:object]
      write ";"
      write "var target="
      emit_exp node.attrs[:target]
      write ";"
      keys = node.attrs[:keys]
      if keys.size > 0
        write "var keys="
        write "["
        write_list_items(keys) do |key|
          write_string key
        end
        write "];"
        write "for(var i=0;i<keys.length;i+=1){"
        write "var key=keys[i];"
      else
        write "for(var key in target){"
      end
      write "obj[key]||(obj[key]=target[key]);"
      write "}"
      write "return obj;"
      write "}()"
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
      write_list_items(list){|node| emit_exp(node)}
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
      if obj_exp.kind == :access
        emit_get_attribute obj_exp.attrs[:object], obj_exp.attrs[:attribute]
      else
        emit_exp obj_exp
      end
      write "."
      write key
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
      emit_get_attribute node.attrs[:object], key
    end


    def emit_class node
      prototype = node.attrs[:prototype]
      write "function(){"
      write "var klass=function(){this.init&&(this.init.apply(this, arguments));};"
      write "klass.prototype="
      emit_object prototype
      write ";"
      write "return klass;"
      write "}()"
    end

    def emit_literal node
      case node.attrs[:type]
      when :num
        emit_num node
      when :lambda
        emit_lambda node
      when :array
        emit_array node
      when :string
        emit_string node
      when :object
        emit_object node
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

    def emit_lambda node
      write "function("
      write node.attrs[:params].join(",")
      write "){"
      emit_variables_define node
      emit_seq node.children[0]
      write "}"
    end

    def write_list_items items
      limit = items.size - 1
      items.each_with_index do |elem, i|
        yield elem
        write "," if i < limit
      end
    end

    def emit_object node
      write "{"
      write_list_items(node.attrs[:val]) do |k, v|
        write_string k
        write ":"
        emit_exp v
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

    def emit_var_assign left, value
      emit_id left
      write "="
      emit_exp value
    end

    def emit_instance_var_set left, value
      emit_exp left.attrs[:object]
      write "."
      write left.attrs[:attribute]
      write "="
      emit_exp value
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
      var_list.each_with_index do |var, i|
        write var.attrs[:name]
        write "="
        write t_var
        write "["
        write i
        write "];"
      end
    end

    def emit_or_assign node
      emit_exp node.attrs[:left]
      write "||("
      emit_left_assign node.attrs[:left], node.attrs[:value]
      write ")"
    end

    def emit_print node
      write "console.log("
      emit_exp node.children[0]
      write ")"
    end
  end
end

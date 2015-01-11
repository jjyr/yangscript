require './lexer_helper'
require './common'
require './external_lexer'

module Yang
  class Lexer

    class Token
      attr_accessor :token, :token_str, :current_token_char_count

      def initialize token, token_str, current_token_char_count
        @token, @token_str, @current_token_char_count = token, token_str, current_token_char_count
      end
    end

    include LexerHelper

    DEFAULT_OPTIONS = {trace_scan: false}.freeze

    attr_reader :line_no, :current_minor_lexer

    def initialize source, options = {}
      options = DEFAULT_OPTIONS.merge options
      @line = nil
      @line_index = 0
      @line_no = 0
      @line_size = 0
      @current_token_char_count = 0
      @eof_flag = false
      @trace_scan = options[:trace_scan]
      @source = source.dup
      @minor_lexers = {}
      register_minor_lexer :external_lexer, ExternalLexer
    end

    def register_minor_lexer name, klass
      lexer = klass.new(self)
      lexer.name = name
      @minor_lexers[name] = lexer
    end

    def use_minor_lexer lexer
      @current_minor_lexer = @minor_lexers[lexer]
      @current_minor_lexer.nil? and raise "cannot find minor lexer #{lexer}"
    end

    def use_main_lexer
      @current_minor_lexer = nil
    end

    def use_lexer lexer
      if lexer
        use_minor_lexer lexer
      else
        use_main_lexer
      end
    end

    def use_lexer_in_context lexer
      old_lexer = current_minor_lexer
      old_lexer = current_minor_lexer.name if current_minor_lexer
      use_lexer lexer
      result = yield
      use_lexer old_lexer
      result
    end

    def get_next_char
      if @line_size > 0 && @line_index == @line_size
        @line_index += 1
        @current_token_char_count += 1
        '\n'
      elsif @line_index >= @line_size
        @line_no += 1
        if @line = @source[@line_no - 1]
          @line_size = @line.size
          @line_index = 0
          @line_index += 1
          @current_token_char_count += 1
          @line[@line_index - 1]
        else
          @eof_flag = true;
          nil
        end
      else
        @current_token_char_count += 1
        @line_index += 1
        @line[@line_index - 1]
      end
    end

    def put_char_back
      if !@eof_flag
        @line_index -= 1
        @current_token_char_count -= 1
      end
    end

    def reserved_lookup id
      RESERVED_WORDS[id] || :id
    end

    def token_str
      @last_token.token_str
    end

    def token
      @last_token.token
    end

    def token_info
      @last_token
    end

    def next_token
      token = token_str = nil
      @current_token_char_count = 0
      if lexer = current_minor_lexer
        token, token_str = lexer.next_token
      else
        token, token_str = _next_token
      end

      @last_token = Token.new token, token_str, @current_token_char_count
    end

    def back_token
      @last_token.current_token_char_count.times do
        put_char_back
      end
    end

    def set_current token
      @last_token = token
    end

    def retoken
      back_token
      next_token
    end

    def _next_token
      state = :start
      save = true
      token = nil
      token_str = ""

      while(state != :done)
        c = get_next_char
        save = true
        case(state)
        when :start
          if (isdigit(c))
            state = :innum
          elsif (isalpha(c))
            state = :inid
          elsif (c == '"')
            save = false
            state = :instr
          elsif (c == '=')
            state = :ineq
          elsif(c == '&')
            state = :inand
          elsif(c == '|')
            state = :inor
          elsif(c == '-')
            state = :inarrow
          elsif(isblank c)
            save = false
          elsif (c == '#')
            save = false
            state = :incomment
          else
            state = :done
            case c
            when nil
              save = false
              token = :endfile
            when '`'
              token = :backquote
            when '@'
              token = :at
            when '<'
              token = :lt
            when '>'
              token = :gt
            when '('
              token = :lparen
            when ')'
              token = :rparen
            when '['
              token = :lbracket
            when ']'
              token = :rbracket
            when '{'
              token = :lbrace
            when '}'
              token = :rbrace
            when '+'
              token = :plus
            when '*'
              token = :star
            when '/'
              token = :slash
            when '%'
              token = :mod
            when ','
              token = :comma
            when '.'
              token = :dot
            when ':'
              token = :colon
            when ';'
              token = :semi
            when '\n'
              token = :newline
            when '!'
              state = :not
            else
              token = :error
            end
          end
        when :incomment
          save = false
          if c.nil?
            state = :done
            token = :endfile
          elsif (c == '\n')
            save = true
            state = :done
            token = :newline
          end
        when :ineq
          state = :done
          if(c == '=')
            token = :eq
          else
            put_char_back
            save = false
            token = :assign
          end
        when :innum
          if (!isdigit(c))
            save = false
            put_char_back
            token = :num
            state = :done
          end
        when :inid
          if(!isalpha(c))
            save = false
            put_char_back
            token = :id
            state = :done
          end
        when :instr
          if(c == '"')
            save = false
            token = :string
            state = :done
          end
        when :inand
          state = :done
          if(c == '&')
            token = :and
          else
            save = false
            token = :b_and
          end
        when :inor
          if(c == '|')
            state = :inor_assign
          else
            state = :done
            save = false
            token = :b_or
          end
        when :inarrow
          state = :done
          if(c == '>')
            token = :arrow
          else
            put_back_char
            save = false
            token = :dash
          end
        when :inor_assign
          state = :done
          if(c == '=')
            token = :or_assign
          else
            save = false
            token = :or
          end
        else
          puts "Scanner Bug: state= #{state}"
          state = :done
          token = :error
        end

        token_str << c if save

        if(state == :done)
          token = reserved_lookup(token_str) if token == :id
        end
      end

      if @trace_scan
        print "\t#{@line_no}: "
        Utils.print_token token, token_str
      end

      [token, token_str]
    end
  end
end

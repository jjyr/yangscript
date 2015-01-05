require './lexer_helper'
require './common'
require './external_lexer'

module Yang
  class Lexer

    include LexerHelper

    DEFAULT_OPTIONS = {trace_scan: false}.freeze

    attr_reader :line_no, :token, :token_str, :current_minor_lexer

    def initialize source, options = {}
      options = DEFAULT_OPTIONS.merge options
      @line = nil
      @line_index = 0
      @line_no = 0
      @line_size = 0
      @eof_flag = false
      @trace_scan = options[:trace_scan]
      @source = source.dup
      @minor_lexers = {}
      register_minor_lexer :external_lexer, ExternalLexer
    end

    def register_minor_lexer name, klass
      @minor_lexers[name] = klass.new(self)
    end

    def use_minor_lexer lexer
      @current_minor_lexer = @minor_lexers[lexer]
      @current_minor_lexer.nil? and raise "cannot find minor lexer #{lexer}"
    end

    def use_main_lexer
      @current_minor_lexer = nil
    end

    def get_next_char
      if @line_size > 0 && @line_index == @line_size
        @line_index += 1
        '\n'
      elsif @line_index >= @line_size
        @line_no += 1
        if @line = @source[@line_no - 1]
          @line_size = @line.size
          @line_index = 0
          @line_index += 1
          @line[@line_index - 1]
        else
          @eof_flag = true;
          nil
        end
      else
        @line_index += 1
        @line[@line_index - 1]
      end
    end

    def put_char_back
      @line_index -= 1 if !@eof_flag
    end

    def reserved_lookup id
      RESERVED_WORDS[id] || :id
    end

    def next_token
      token = token_str = nil
      if lexer = current_minor_lexer
        token, token_str = lexer.next_token
      else
        token, token_str = _next_token
      end

      @token, @token_str = token, token_str
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
              token = :external_begin
              use_minor_lexer :external_lexer
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
            when '-'
              token = :dash
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

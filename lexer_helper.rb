module Yang
  module LexerHelper
    def isblank c
      c =~ /\A\s\z/
    end

    def isdigit c
      c =~ /\A\d\z/
    end

    def isalpha c
      c =~ /\A[A-Za-z_]\z/
    end
  end

  class LexerBase
    include LexerHelper

    DEFAULT_OPTIONS = {trace_scan: false}.freeze

    attr_reader :line_no, :token, :token_str

    def initialize source, options = {}
      options = DEFAULT_OPTIONS.merge options
      @line = nil
      @line_index = 0
      @line_no = 0
      @line_size = 0
      @eof_flag = false
      @trace_scan = options[:trace_scan]
      @source = source.dup
    end

    def next_token
      raise NotImplementedError
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

    def put_back_char
      @line_index -= 1 if !@eof_flag
    end
  end
end

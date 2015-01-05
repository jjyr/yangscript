require './minor_lexer'

module Yang
  class EmbedResult
    def initialize token, token_str
      case token
      when :raw
        @raw = true
      when :embed
        @embed = true
      else
        raise "embed parser result error, token: #{token}, token_str: #{token_str}"
      end
      @value = token_str
    end

    attr_reader :raw, :embed
    attr_accessor :value
  end

  class EmbedLexer
    include MinorLexer

    def initialize main, raw_end
      super(main)
      @raw_end = raw_end
    end

    def detect_embed_start
      is_embed = false
      if get_next_char == "@"
        if get_next_char == "{"
          is_embed = true
        end
        put_char_back # '{'
      end
      put_char_back # '@'
      is_embed
    end

    def next_token
      state = :start
      token = nil
      token_str = ""
      while(state != :done)
        c = get_next_char
        case state
        when :start
          if c == @raw_end
            state = :done
            save = false
            token = :end
          elsif detect_embed_start
            state = :inembed
          else
            state = :inraw
          end
        when :inraw
          if (c == @raw_end) || detect_embed_start
            token = :raw
            state = :done
            put_char_back
          else
            token_str << c
          end
        when :inembed
          put_char_back
          token, token_str = @main._next_token
          state = :done
          binding.pry
          p token
          if c == '}'
            token = :embed
            state = :done
            save = false
          end
        else
          raise "should not excute here, current state is #{state}"
        end
      end

      [token, token_str]
    end

    def parse
      result == []
      loop do
        token, token_str = next_token
        break if token == :end
        result << EmbedResult.new(token, token_str)
      end
      result
    end
  end
end

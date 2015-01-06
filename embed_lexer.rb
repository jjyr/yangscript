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

    def initialize main, external_end
      super(main)
      @external_end = external_end
      @init_state = :start
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
      state = @init_state
      token = nil
      token_str = ""
      while(state != :done)
        c = get_next_char
        case state
        when :start
          if c == @external_end
            state = :done
            token = :end
          else
            put_char_back
            if detect_embed_start
              state = :inembed
            else
              state = :inraw
            end
          end
        when :inraw
          put_char_back
          if detect_embed_start
            token = :raw
            state = :done
          elsif (c == @external_end)
            token = :raw
            state = :done
          else
            token_str << get_next_char
          end
        when :inembed
          @init_state = :inembed
          put_char_back
          token, token_str = @main._next_token
          state = :done

          if token == :rbrace
            @init_state = :start
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

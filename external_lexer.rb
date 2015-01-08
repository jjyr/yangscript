require './embed_lexer'

module Yang
  class ExternalLexer
    include MinorLexer

    EXTERNAL_END = '`'.freeze

    def initialize main
      super(main)
      @embed_lexer = EmbedLexer.new main, EXTERNAL_END
    end

    def keep_state_during_embed &block
      @embed_lexer.keep_state &block
    end

    def next_token
      token, token_str = @embed_lexer.next_token
      case token
      when :raw
        token = :external_fragment
      when :end
        token = :backquote
        token_str = EXTERNAL_END
      end
      [token, token_str]
    end
  end
end

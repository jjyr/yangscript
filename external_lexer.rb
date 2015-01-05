require './embed_lexer'

module Yang
  class ExternalLexer
    include MinorLexer

    EXTERNAL_END = '`'.freeze

    def initialize main
      super(main)
      @embed_lexer = EmbedLexer.new main, EXTERNAL_END
    end

    def next_token
      token, token_str = @embed_lexer.next_token
      case token
      when :raw
        token = :external_fragment
      when :end
        @main.use_main_lexer
        token = :external_end
      end
      [token, token_str]
    end
  end
end

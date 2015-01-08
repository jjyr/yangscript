module Yang
  module MinorLexer

    attr_accessor :name
    
    def initialize main_parser
      @main = main_parser
    end

    def get_next_char
      @main.get_next_char
    end

    def put_char_back
      @main.put_char_back
    end
  end
end

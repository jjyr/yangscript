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
end

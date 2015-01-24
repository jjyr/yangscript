module Yang
  module LexerHelper
    def isblank c
      c =~ /\A\s\z/
    end

    def isdigit c
      c =~ /\A\d\z/
    end

    def isid c
      (c =~ /\A[^\^\&\`\%\*\$\#\@\!\~\(\)\-\+\=\?\'\"\:\;\<\>\/\.\,\[\]\{\}\|\\]\z/) && !isblank(c)
    end

    def isidcap c
      !isdigit(c) && isid(c)
    end
  end
end

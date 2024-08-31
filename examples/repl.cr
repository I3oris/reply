require "../src/reply"
require "tartrazine/formatters/ansi"

class MyReader < Reply::Reader
  @formatter : Tartrazine::Ansi
  @lexer : Tartrazine::BaseLexer

  def initialize(@language : String)
    super()
    @lexer = Tartrazine.lexer(@language)
    @formatter = Tartrazine::Ansi.new()
  end

  def highlight(expression : String) : String
    @formatter.format(expression, @lexer)
  end
end

language = "bash"

reader = MyReader.new(language)

reader.read_loop do |expression|
  # Eval expression here
  puts " => #{expression}"
end

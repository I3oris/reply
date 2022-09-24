require "../src/reply"
require "crystal/syntax_highlighter/colorize"
require "compiler/crystal/tools/formatter"

CRYSTAL_KEYWORD = %w(
  abstract alias annotation asm begin break case class
  def do else elsif end ensure enum extend for fun
  if in include instance_sizeof lib macro module
  next of offsetof out pointerof private protected require
  rescue return select sizeof struct super
  then type typeof union uninitialized unless until
  verbatim when while with yield
)

CLOSING_KEYWORD  = %w(end \) ] })
UNINDENT_KEYWORD = %w(else elsif when in rescue ensure in when)

class CrystalInterface < Reply::Interface
  def prompt(io : IO, line_number : Int32, color? : Bool) : Nil
    io << "crystal".colorize.blue.toggle(color?)
    io << ':'
    io << sprintf("%03d", line_number)
    io << "> "
  end

  def highlight(expression : String) : String
    Crystal::SyntaxHighlighter::Colorize.highlight!(expression)
  end

  def continue?(expression : String) : Bool
    Crystal::Parser.new(expression).parse
    false
  rescue e : Crystal::CodeError
    # e.unterminated? ? true : false
    false
  end

  def format(expression : String) : String?
    Crystal.format(expression).chomp rescue nil
  end

  def indentation_level(expression_before_cursor : String) : Int32?
    parser = Crystal::Parser.new(expression_before_cursor)
    parser.parse rescue nil

    parser.type_nest + parser.def_nest + parser.fun_nest
  end

  def word_delimiters : Regex
    # `"`, `:`, `'`, are not a delimiter because symbols and strings should be treated as one word.
    # '=', !', '?' are not a delimiter because they could make part of method name.
    /[ \n\t\+\-\*\/,;@&%<>\^\\\[\]\(\)\{\}\|\.\~]/
  end

  # TODO:
  # def reindent_line(indent, line)
  #   case line.strip
  #   when .in? CLOSING_KEYWORD then indent
  #   when .in? UNINDENT_KEYWORD then indent - 1
  #   else
  #     nil
  #   end
  # end

  def replace_on_char(line, x)
    line = line.rstrip(' ')
    return nil if x != line.size

    keyword = line.lstrip(' ')

    expr = @editor.expression_before_cursor # /!\

    case keyword
    when Nil
    when .in? CLOSING_KEYWORD
      replacement = "  "*self.indentation_level(expr) + keyword
    when .in? UNINDENT_KEYWORD
      indent = {self.indentation_level(expr) - 1, 0}.max
      replacement = "  "*indent + keyword
    end

    replacement
  end

  def save_in_history?(expression : String) : Bool
    !expression.blank?
  end

  def auto_complete(name_filter : String, expression : String) : {Array(String), String}
    return CRYSTAL_KEYWORD.dup, "Keywords"
  end
end

repl_interface = CrystalInterface.new

repl_interface.run do |expression|
  case expression
  when "clear_history"
    repl_interface.clear_history
  when "reset"
    repl_interface.reset
  when "exit"
    break
  when .presence
    # Eval expression here
    puts " => #{expression}"
  end
end

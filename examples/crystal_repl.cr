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
UNINDENT_KEYWORD = %w()

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

  def reindent_line(line)
    case line.strip
    when "end", ")", "]", "}"
      0
    when "else", "elsif", "rescue", "ensure", "in", "when"
      -1
    else
      nil
    end
  end

  def save_in_history?(expression : String) : Bool
    !expression.blank?
  end

  def auto_complete(name_filter : String, expression : String) : {String, Array(String)}
    return "Keywords:", CRYSTAL_KEYWORD.dup
  end

  def auto_completion_display_title(io : IO, title : String)
    io << title
  end

  def auto_completion_display_selected_entry(io : IO, entry : String)
    io << entry.colorize.red.bright
  end

  def auto_completion_display_entry(io : IO, entry_matched : String, entry_remaining : String)
    io << entry_matched.colorize.red.bright << entry_remaining
  end
end

repl_interface = CrystalInterface.new

repl_interface.run do |expression|
  case expression
  when "clear_history"
    repl_interface.history.clear
  when "reset"
    repl_interface.reset
  when "exit"
    break
  when .presence
    # Eval expression here
    puts " => #{expression}"
  end
end

require "../src/reply"
require "colorize"

record Movie, name : String, director_name : String, duration : String do
  def to_s(io : IO)
    io.puts "Name: #{@name}"
    io.puts "Director name: #{@director_name}"
    io.puts "Duration: #{@duration}"
  end
end

class MyFavoriteMovies
  class_getter movies = [] of Movie
end

def term_width
  Reply::Term::Size.width
end

class MyReader < Reply::Reader
  include Commands

  def gets(label, optional = false) : String
    answer = nil

    until answer && answer.presence
      print label
      answer = gets

      (return answer || "") if optional
    end

    answer
  end

  def display(movies)
    puts " Movies: ".center(term_width, '=')
    puts movies.join("-"*term_width)
    puts "="*term_width
  end

  @[Help("Add a movie to my collection", details: "\nusage: add [movie_name]")]
  def do_add(name = nil)
    name ||= gets "Movie name: "
    director_name = gets "Director name: ", optional: true
    duration = gets "Duration (hh:mm): ", optional: true

    MyFavoriteMovies.movies << Movie.new(name.strip(%("')), director_name, duration)
  end

  @[Help("List all movies in my collection")]
  def do_list
    display(MyFavoriteMovies.movies)
  end

  @[Help("Search a movie by its name", details: "\nusage: search <movie_name>")]
  def do_search(name)
    name = name.strip(%("'))

    results = MyFavoriteMovies.movies.select(&.name.downcase.includes?(name.downcase))
    puts "#{results.size} movie(s) with name '#{name}' found"
    display(results) unless results.empty?
  end

  @[Help("Delete a movie by its exact name", details: "\nusage: delete <movie_name>")]
  def do_delete(name)
    name = name.strip(%("'))

    results = MyFavoriteMovies.movies.select(&.name.== name)
    if results.empty?
      puts "No movie named '#{name}' to delete"
      return
    end
    results.each do |movie|
      MyFavoriteMovies.movies.delete(movie)
    end
    puts "#{results.size} movie(s) deleted"
  end

  @[Help("Sort my movies by name", details: "\nusage: sort [by-name|by-director]")]
  def do_sort(by = "by-name")
    case by
    when "by-name"     then MyFavoriteMovies.movies.sort_by! &.name
    when "by-director" then MyFavoriteMovies.movies.sort_by! &.director_name
    else                    return do_help("sort")
    end
    puts "#{MyFavoriteMovies.movies.size} movie(s) sorted"
  end

  @[Help("Print the given arguments", details: "\nusage: echo [arguments]...")]
  def do_echo(*arguments)
    puts arguments.first.join ' '
  end

  @[Exit]
  @[Help("Exit the prompt")]
  def do_exit
  end

  def highlight(expression : String) : String
    words = expression.split(' ')

    # Macro `command_names` gives all defined commands
    if words.first.in? command_names
      return "#{words.first.colorize.bold.cyan}#{expression[words.first.size..]}"
    end

    expression
  end

  # Add auto-completion for commands
  def auto_complete_arguments(command_name : String, name_filter : String, expression_before : String) : {String, Array(String)}
    if command_name == "sort"
      return {command_name, %w(by-name by-director)}
    end
    {"", [] of String}
  end

  # Uncomment to override the behavior on unknown command
  # def unknown_command(command_name : String, arguments : Array(String))
  #   output.puts "Unknown command: #{command_name}"
  #   output.print "Available commands are: "
  #   output.puts command_names.join(", ") { |cmd| highlight(cmd) }
  #   output.puts
  #   do_help
  # end

  # # Uncomment to override whole help message
  # def do_help(command_name : String? = nil)
  #   docs = command_docs({{@def.annotation(Help) ? @def.annotation(Help)[0] : nil}})

  #   if command_name = command_name.presence
  #     if command_doc = docs[command_name]?
  #       output.puts "#{highlight(command_name)}: #{command_doc[:summary]}"
  #       output.puts command_doc[:details] if command_doc[:details]?
  #     else
  #       unknown_command(command_name, [] of String)
  #     end
  #   else
  #     longest_name = command_names.max_by(&.size)
  #     docs.each do |name, doc|
  #       output.print " "*(longest_name.size - name.size)
  #       output.puts "#{highlight(name)}: #{doc[:summary]}"
  #     end
  #   end
  # end

  # # Uncomment to override the help doc
  # @[Help("Show this help!")]
  # def do_help(command_name = nil)
  #   super
  # end
end

reader = MyReader.new

puts " My Favorite Movies ".center(term_width, '=')
puts
puts "Welcome to the favorite movies prompt, a sample prompt for saving movies and quickly search them."
puts
puts "Type #{reader.highlight("help")} to know available commands."
puts "="*term_width

reader.run_commands_loop

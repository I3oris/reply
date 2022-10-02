# REPLy

REPLy is a shard to create REPL interface: (Read Eval Print Loop).

It handles the `Read` & `Print` part of the `Loop`, and can be a alternative to [readline](https://github.com/crystal-lang/crystal-readline).

## Features

It includes the following features:
* Multiline input
* History
* Pasting of large expressions
* Hook for Syntax highlighting
* Hook for Auto formatting
* Hook for Auto indentation
* Hook for Auto completion (Experimental)

It doesn't support yet:
* Saving history in a file
* History reverse i-search
* Customizable hotkeys
* Window compatibility (Not tested yet)
* Unicode characters

NOTE: REPLy was extracted from https://github.com/I3oris/ic, it was first designed to fit exactly the usecase of a crystal interpreter, so don't hesitate to open an issue to make REPLy more generic and suitable for your project if needed.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     reply:
       github: I3oris/reply
   ```

2. Run `shards install`

## Usage

### Minimal example

```crystal
require "reply"

repl_interface = Reply::Interface.new
repl_interface.run do |expression|
  # Eval expression here
  puts " => #{expression}"
end
```

### Customize the Interface

```crystal
require "../src/reply"

class MyInterface < Reply::Interface
  def prompt(io : IO, line_number : Int32, color? : Bool) : Nil
    # Display a custom prompt
  end

  def highlight(expression : String) : String
    # Highlight the expression
  end

  def continue?(expression : String) : Bool
    # Return whether the interface should continue on multiline, depending of the expression
  end

  def format(expression : String) : String?
    # Reformat when expression is submitted
  end

  def indentation_level(expression_before_cursor : String) : Int32?
    # Compute the indentation from the expression
  end

  def word_delimiters : Regex
    # Return the word delimiters used for pick the word for auto-completion
  end

  def save_in_history?(expression : String) : Bool
    # Return whether the expression is saved in history
  end

  def auto_complete(name_filter : String, expression : String) : {String, Array(String)}
    # Return the auto-completion result from expression
  end
end
```

## Development

Free to pull request!

## Contributing

1. Fork it (<https://github.com/I3oris/reply/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [I3oris](https://github.com/I3oris) - creator and maintainer

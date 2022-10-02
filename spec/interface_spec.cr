require "./spec_helper"

module Reply
  describe Interface do
    it "reads char" do
      interface = SpecHelper.interface
      reader, writer = IO.pipe

      spawn do
        interface.read_next(from: reader).should eq "a"
        interface.read_next(from: reader).should eq "♥💎"
      end

      SpecHelper.send(writer, 'a')
      SpecHelper.send(writer, '\n')

      SpecHelper.send(writer, '♥')
      SpecHelper.send(writer, '💎')
      SpecHelper.send(writer, '\n')
    end

    it "reads string" do
      interface = SpecHelper.interface
      reader, writer = IO.pipe

      spawn do
        interface.read_next(from: reader).should eq "Hello"
        interface.read_next(from: reader).should eq "class Foo\n  def foo\n    42\n  end\nend"
      end

      SpecHelper.send(writer, "Hello")
      SpecHelper.send(writer, '\n')

      SpecHelper.send(writer, <<-END)
        class Foo
          def foo
            42
          end
        end
        END
      SpecHelper.send(writer, '\n')
    end

    it "uses directional arrows" do
      interface = SpecHelper.interface
      reader, writer = IO.pipe

      spawn do
        interface.read_next(from: reader)
      end

      SpecHelper.send(writer, <<-END)
        class Foo
          def foo
            42
          end
        end
        END
      SpecHelper.send(writer, "\e[A") # up
      SpecHelper.send(writer, "\e[C") # right
      SpecHelper.send(writer, "\e[B") # down
      SpecHelper.send(writer, "\e[D") # left
      interface.editor.verify(x: 2, y: 4)

      SpecHelper.send(writer, '\0')
    end

    it "uses back" do
      interface = SpecHelper.interface
      reader, writer = IO.pipe

      spawn do
        interface.read_next(from: reader).should eq "Hey"
        interface.read_next(from: reader).should eq "ab"
        interface.read_next(from: reader).should eq ""
      end

      SpecHelper.send(writer, "Hello")
      SpecHelper.send(writer, '\u{7f}') # back
      SpecHelper.send(writer, '\u{7f}')
      SpecHelper.send(writer, '\u{7f}')
      SpecHelper.send(writer, 'y')
      SpecHelper.send(writer, '\n')

      SpecHelper.send(writer, "a\nb")
      SpecHelper.send(writer, "\e[D") # left
      SpecHelper.send(writer, '\u{7f}')
      SpecHelper.send(writer, '\n')

      SpecHelper.send(writer, "")
      SpecHelper.send(writer, '\u{7f}')
      SpecHelper.send(writer, '\n')
    end

    it "deletes" do
      interface = SpecHelper.interface
      reader, writer = IO.pipe

      spawn do
        interface.read_next(from: reader).should eq "Hey"
        interface.read_next(from: reader).should eq "ab"
        interface.read_next(from: reader).should eq ""
      end

      SpecHelper.send(writer, "Hello")
      SpecHelper.send(writer, "\e[D") # left
      SpecHelper.send(writer, "\e[D")
      SpecHelper.send(writer, "\e[D")
      SpecHelper.send(writer, "\e[3~") # delete
      SpecHelper.send(writer, "\e[3~")
      SpecHelper.send(writer, "\e[3~")
      SpecHelper.send(writer, 'y')
      SpecHelper.send(writer, '\n')

      SpecHelper.send(writer, "a\nb")
      SpecHelper.send(writer, "\e[D")
      SpecHelper.send(writer, "\e[D")
      SpecHelper.send(writer, "\e[3~")
      SpecHelper.send(writer, '\n')

      SpecHelper.send(writer, "")
      SpecHelper.send(writer, "\e[3~")
      SpecHelper.send(writer, '\n')
    end

    it "uses tabulation" do
      interface = SpecHelper.interface
      reader, writer = IO.pipe

      spawn do
        interface.read_next(from: reader)
      end

      SpecHelper.send(writer, "42.")
      interface.auto_completion.verify(open: false)

      SpecHelper.send(writer, '\t')
      interface.auto_completion.verify(open: true, entries: %w(hello world hey))
      interface.editor.verify("42.")

      SpecHelper.send(writer, 'w')
      interface.auto_completion.verify(open: true, entries: %w(world), name_filter: "w")
      interface.editor.verify("42.w")

      SpecHelper.send(writer, '\u{7f}') # back
      interface.auto_completion.verify(open: true, entries: %w(hello world hey))
      interface.editor.verify("42.")

      SpecHelper.send(writer, 'h')
      interface.auto_completion.verify(open: true, entries: %w(hello hey), name_filter: "h")
      interface.editor.verify("42.h")

      SpecHelper.send(writer, '\t')
      interface.auto_completion.verify(open: true, entries: %w(hello hey), name_filter: "h", selection_pos: 0)
      interface.editor.verify("42.hello")

      SpecHelper.send(writer, '\t')
      interface.auto_completion.verify(open: true, entries: %w(hello hey), name_filter: "h", selection_pos: 1)
      interface.editor.verify("42.hey")

      SpecHelper.send(writer, '\t')
      interface.auto_completion.verify(open: true, entries: %w(hello hey), name_filter: "h", selection_pos: 0)
      interface.editor.verify("42.hello")

      SpecHelper.send(writer, "\e\t") # shit_tab
      interface.auto_completion.verify(open: true, entries: %w(hello hey), name_filter: "h", selection_pos: 1)
      interface.editor.verify("42.hey")

      SpecHelper.send(writer, '\u{7f}') # back
      SpecHelper.send(writer, 'l')
      SpecHelper.send(writer, '\t')
      interface.auto_completion.verify(open: true, entries: %w(hello), name_filter: "hel", selection_pos: 0)
      interface.editor.verify("42.hello")

      SpecHelper.send(writer, ' ')
      interface.auto_completion.verify(open: false, cleared: true)
      interface.editor.verify("42.hello ")

      SpecHelper.send(writer, '\0')
    end

    it "uses escape" do
      interface = SpecHelper.interface
      reader, writer = IO.pipe

      spawn do
        interface.read_next(from: reader)
      end

      SpecHelper.send(writer, "42.")
      interface.auto_completion.verify(open: false)

      SpecHelper.send(writer, '\t')
      interface.auto_completion.verify(open: true, entries: %w(hello world hey))

      SpecHelper.send(writer, '\e') # escape
      interface.auto_completion.verify(open: false)
    end

    it "uses alt-enter" do
      interface = SpecHelper.interface
      reader, writer = IO.pipe

      spawn do
        interface.read_next(from: reader).should eq "Hello\nWorld"
      end

      SpecHelper.send(writer, "Hello")
      SpecHelper.send(writer, "\e\r") # alt-enter
      SpecHelper.send(writer, "World")
      interface.editor.verify("Hello\nWorld")
      SpecHelper.send(writer, "\n")
    end

    it "uses ctrl-c" do
      interface = SpecHelper.interface
      reader, writer = IO.pipe

      spawn do
        interface.read_next(from: reader).should be_nil
      end

      SpecHelper.send(writer, "Hello")
      SpecHelper.send(writer, '\u{3}') # ctrl-c
      interface.editor.verify("")

      SpecHelper.send(writer, '\0')
    end

    it "uses ctrl-d & ctrl-x" do
      interface = SpecHelper.interface
      reader, writer = IO.pipe

      spawn do
        interface.read_next(from: reader).should be_nil
        interface.read_next(from: reader).should be_nil
      end

      SpecHelper.send(writer, "Hello")
      SpecHelper.send(writer, '\u{4}') # ctrl-d

      SpecHelper.send(writer, "World")
      SpecHelper.send(writer, '\u{24}') # ctrl-x
    end

    it "resets" do
      interface = SpecHelper.interface
      reader, writer = IO.pipe

      spawn do
        interface.read_next(from: reader)
        interface.read_next(from: reader)
      end

      SpecHelper.send(writer, "Hello\nWorld")
      SpecHelper.send(writer, '\n')
      interface.line_number.should eq 3

      interface.reset
      interface.line_number.should eq 1

      SpecHelper.send(writer, '\0')
    end
  end
end

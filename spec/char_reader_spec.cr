require "./spec_helper"

module Reply
  describe CharReader do
    it "read chars" do
      reader = SpecHelper.char_reader

      reader.verify_read('a', expect: ['a', :exit])
      reader.verify_read("Hello", expect: ["Hello", :exit])
    end

    it "read ANSI escape sequence" do
      reader = SpecHelper.char_reader

      reader.verify_read("\e[A", expect: [:up, :exit])
      reader.verify_read("\e[B", expect: [:down, :exit])
      reader.verify_read("\e[C", expect: [:right, :exit])
      reader.verify_read("\e[D", expect: [:left, :exit])
      reader.verify_read("\e[3~", expect: [:delete, :exit])
      reader.verify_read("\e[1;5A", expect: [:ctrl_up, :exit])
      reader.verify_read("\e[1;5B", expect: [:ctrl_down, :exit])
      reader.verify_read("\e[1;5C", expect: [:ctrl_right, :exit])
      reader.verify_read("\e[1;5D", expect: [:ctrl_left, :exit])
      reader.verify_read("\e[H", expect: [:move_cursor_to_begin, :exit])
      reader.verify_read("\e[F", expect: [:move_cursor_to_end, :exit])
      reader.verify_read("\eOH", expect: [:move_cursor_to_begin, :exit])
      reader.verify_read("\eOF", expect: [:move_cursor_to_end, :exit])
      reader.verify_read("\e[1~", expect: [:move_cursor_to_begin, :exit])
      reader.verify_read("\e[4~", expect: [:move_cursor_to_end, :exit])

      reader.verify_read("\e\t", expect: [:shift_tab, :exit])
      reader.verify_read("\e\r", expect: [:insert_new_line, :exit])
      reader.verify_read("\e", expect: [:escape, :exit])
      reader.verify_read("\n", expect: [:enter, :exit])
      reader.verify_read("\t", expect: [:tab, :exit])

      reader.verify_read('\0', expect: [:exit])
      reader.verify_read('\u0001', expect: [:move_cursor_to_begin, :exit])
      reader.verify_read('\u0003', expect: [:keyboard_interrupt, :exit])
      reader.verify_read('\u0004', expect: [:exit])
      reader.verify_read('\u0005', expect: [:move_cursor_to_end, :exit])
      reader.verify_read('\u0018', expect: [:exit])
      reader.verify_read('\u007F', expect: [:back, :exit])
    end

    it "read large buffer" do
      reader = SpecHelper.char_reader(buffer_size: 1024)

      reader.verify_read(
        "a"*10_000,
        expect: ["a" * 1024]*9 + ["a"*(10_000 - 9*1024), :exit]
      )
    end
  end
end

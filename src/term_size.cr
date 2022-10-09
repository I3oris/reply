lib LibC
  struct Winsize
    row : LibC::Short
    col : LibC::Short
    x_pixel : LibC::Short
    y_pixel : LibC::Short
  end

  # TIOCGWINSZ is a magic number passed to ioctl that requests the current
  # terminal window size. It is platform dependent (see
  # https://stackoverflow.com/a/4286840).
  {% begin %}
    {% if flag?(:darwin) || flag?(:bsd) %}
      TIOCGWINSZ = 0x40087468
    {% elsif flag?(:unix) %}
      TIOCGWINSZ = 0x5413
    {% end %}
  {% end %}

  fun ioctl(fd : LibC::Int, request : LibC::SizeT, winsize : LibC::Winsize*) : LibC::Int
end

module Reply::Term
  module Size
    # Gets the terminals width
    def self.size : {Int32, Int32}
      ret = LibC.ioctl(1, LibC::TIOCGWINSZ, out screen_size)
      raise "Error retrieving terminal size: ioctl TIOCGWINSZ: #{Errno.value}" if ret < 0

      {screen_size.col.to_i32, screen_size.row.to_i32}
    end

    def self.width
      size[0]
    end

    def self.height
      size[1]
    end
  end
end

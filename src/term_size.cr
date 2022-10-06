lib LibC
  struct Winsize
    row : LibC::Short
    col : LibC::Short
    x_pixel : LibC::Short
    y_pixel : LibC::Short
  end

  TIOCGWINSZ = 0x5413 # Magic number.

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

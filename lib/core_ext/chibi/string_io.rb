module Chibi
  class StringIO < ::StringIO
    attr_accessor :filename

    def initialize(*args)
      super(*args[1..-1])
      self.filename = args[0]
    end

    def original_filename
      filename
    end
  end
end

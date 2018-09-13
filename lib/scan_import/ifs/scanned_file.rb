require "fileutils"
require File.join(File.dirname(__FILE__), "..", "code3of9")

module IFS
  class ScannedFile
    FILE_TYPES = {
      "pdf" => "ACROBAT"
    }

    attr_reader :path, :name, :type

    def initialize(fpath, name=nil)
      @path = fpath
      @name = name || Code3of9.decode(
        File.basename(fpath).gsub(/\.[^.]+$/, '').gsub(/&/, "/")
      )
      @type = FILE_TYPES[fpath[/\.([^.]+)$/, 1].downcase]
    end

    def move_to(dir)
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
      FileUtils.mv(path, File.join(dir, File.basename(path)))
    end

    def to_blob
      File.open(path, "rb") {|f| f.read}
    end
  end
end


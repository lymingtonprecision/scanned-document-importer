require 'logger'

module IFS; end

class IFS::Logger < Logger
  class << self
    RETENTION_DAYS = 7

    def last_rentention_time
      seconds_in_a_day = 24 * 60 * 60
      now = Time.now
      Time.mktime(now.year, now.month, now.mday) - (seconds_in_a_day * RETENTION_DAYS)
    end

    def file_execeeds_log_retention_time(cutoff, fname)
      ctime = File.ctime(fname)
      ctime < cutoff
    end

    def cleanup_aged_log_files!(path)
      basedir = File.dirname(path)
      cutoff = last_rentention_time()

      Dir.glob(File.join(basedir, "*.log.txt.*")) do |fname|
        File.delete(fname) if file_execeeds_log_retention_time(cutoff, fname)
      end
    end

    def file_path(basedir)
      File.join(basedir, "log", "import-log.txt")
    end
  end

  def initialize(path)
    @path = path
    super(path, 'daily')
  end

  def close
    super()
    self.class.cleanup_aged_log_files!(@path) if @path.instance_of?(String)
  end
end

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

    def cleanup_aged_log_files!(log, path)
      basedir = File.dirname(path)
      cutoff = last_rentention_time()

      Dir.glob(File.join(basedir, "*.log.txt.*")) do |fname|
        if file_execeeds_log_retention_time(cutoff, fname)
          log.info { "Removing old log file #{fname}" }
          File.delete(fname)
        end
      end
    end

    def file_path(basedir)
      File.join(basedir, "log", "import-log.txt")
    end
  end

  def initialize(path)
    @path = path
    super(path, 'daily')
    self.formatter = proc do |severity, datetime, progname, msg|
      ts = datetime.strftime('%Y-%m-%d %H:%M:%S')
      "[#{ts}] #{severity}: #{msg}\n"
    end
  end

  def close
    self.class.cleanup_aged_log_files!(self, @path) if @path.instance_of?(String)
    super()
  end
end

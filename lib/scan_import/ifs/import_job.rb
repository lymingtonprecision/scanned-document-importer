require File.join(File.dirname(__FILE__), "..", "ifs")

class DateTime
  def to_time
    Time.gm(year, month, day, hour, min, sec)
  end unless method_defined? :to_time
end

module IFS
  class ImportJob
    class File
      BASE_URL = "http://xenon.lymingtonprecision.co.uk:60080/client/runtime/Ifs.Fnd.Explorer.application?url=ifsapf%3AfrmDocumentContainer%3Faction%3Dget%26key1%3D"

      class << self
        def find_for_run(run)
          run_id = run.kind_of?(ImportJob) ? run.id : run
          files = []

          M.database do |d|
            c = d.exec(<<-SQL, run_id
              select
                f.class_name,
                f.doc_no,
                f.doc_class,
                dc.doc_name,
                f.object_lu,
                f.object_key_ref,
                f.filename,
                f.processed_at,
                f.error
              from #{Logger::TBL_PREFIX}_run_files f
              join ifsapp.doc_class dc
                on f.doc_class = dc.doc_class
              where run_id = :run_id
              order by f.processed_at desc
              SQL
            )

            while r = c.fetch
              file = self.new(
                r[0],
                :doc_no       => r[1],
                :doc_class_no => r[2],
                :doc_class    => r[3],
                :obj_lu       => r[4],
                :obj_key      => r[5],
                :filename     => r[6],
                :processed_at => r[7],
                :error        => r[8]
              )

              block_given? ? yield(file) : (files << file)
            end

            c.close
          end

          return block_given? ? nil : files
        end
      end

      attr_reader :scan_class
      attr_reader :doc_no, :doc_class_no, :doc_class
      attr_reader :obj_lu, :obj_key
      attr_reader :filename, :processed_at, :error

      def initialize(scan_class, attrs={})
        @klass = IFS.const_get(scan_class)
        @scan_class = scan_class.to_s.gsub(/([A-Z])/, ' \1').strip
        @doc_no = attrs[:doc_no]
        @doc_no = @doc_no.to_i unless @doc_no.nil?
        @doc_class_no = attrs[:doc_class_no]
        @doc_class_no = @doc_class_no.to_i unless @doc_class_no.nil?
        @doc_class = attrs[:doc_class]
        @obj_lu = attrs[:obj_lu]
        @obj_key = attrs[:obj_key].to_s
        @filename = attrs[:filename]
        @processed_at = attrs[:processed_at]
        @processed_at = @processed_at.to_time if @processed_at.respond_to? :to_time
        @error = attrs[:error]

        if (@error.nil? || @error.empty?) && @doc_no.nil?
          @error = "No matching object found."
        end

        @obj_key = @obj_key.split(/\^/).inject({}) {|h,kv|
          k,v = kv.split(/=/)
          h[k] = v
          h
        }
      end

      def name
        ::File.basename(filename)
      end

      def obj_ref
        if obj_key.empty?
          ""
        elsif @klass
          @klass.obj_ref(obj_key)
        else
          scan_class + " " + obj_key.sort_by {|kv| kv[0]}.collect {|kv|
            "#{kv[0].gsub(/_/, ' ').gsub.capitalize} #{v}"
          }.join(", ")
        end
      end

      def obj_url
        if @klass
          @klass.obj_url(obj_key)
        else
          "#"
        end
      end

      def doc_url
        "#{BASE_URL}#{doc_class_no}%255E#{doc_no}%255EA1%255E1%26COMPANY%3D"
      end

      def error?
        !(error.nil? || error.empty?)
      end
    end

    @queue = :ifs_doc_import

    class << self
      def perform(*obj_classes)
        log = IFS::Object.logger
        run_id = nil
        docs = 0

        IFS.connect do
          begin
            if log.nil?
              log = IFS::Logger.new
              IFS::Object.set_logger log
            end

            run_id = log.start

            obj_classes.each do |obj_class|
              if IFS.const_defined? obj_class
                klass = IFS.const_get(obj_class)
                docs += klass.process_new_documents(run_id)
              end
            end

            if docs == 0
              IFS.rollback
              run_id = nil
            end
          rescue
            if run_id.nil?
              raise $!
            else
              log.error run_id, $!
            end
          ensure
            log.finish(run_id) unless run_id.nil?
          end
        end
      end

      def find(run_id)
        job = nil

        M.database do |d|
          c = d.exec(<<-SQL, run_id
            select
              run_id,
              started_at,
              finished_at,
              error
            from #{Logger::TBL_PREFIX}_runs
            where run_id = :run_id
            SQL
          )

          r = c.fetch
          job = self.new(*r) unless r.nil? || r.empty?
          c.close
        end

        return job
      end

      # :limit => return <<n>> jobs
      # :since => return all jobs run since <<time>>
      def find_all(opts={})
        jobs = []

        limit = opts[:limit]
        params = []
        criteria = ["1=1"]

        unless opts[:since].nil?
          criteria << "started_at >= to_date(:since, 'yyyy-mm-dd hh24:mi:ss')"
          params << opts[:since].strftime("%Y-%m-%d %H:%M:%S")
        end

        M.database do |d|
          c = d.exec(<<-SQL, *params
            select
              run_id,
              started_at,
              finished_at,
              error
            from #{Logger::TBL_PREFIX}_runs
            where #{criteria.join(" and ")}
            order by run_id desc
            SQL
          )

          count = 0
          while r = c.fetch
            break if !limit.nil? && count >= limit
            job = self.new(*r)
            block_given? ? yield(job) : (jobs << job)
            count += 1
          end

          c.close
        end

        return block_given? ? nil : jobs
      end
    end

    attr_reader :id, :started_at, :finished_at, :error, :files

    def initialize(run_id, started, finished, error=nil, files=nil)
      @id = run_id.to_i
      @started_at = started.respond_to?(:to_time) ? started.to_time : started
      @finished_at = finished.respond_to?(:to_time) ? finished.to_time : finished
      @error = error
      @files = files || File.find_for_run(self)
    end

    def error?
      !(error.nil? || error.empty?)
    end

    def has_errors?
      return @has_errors unless @has_errors.nil?
      @has_errors = error? || !files.find {|f| f.error?}.nil?
      return @has_errors
    end

    def classes
      @classes ||= files.inject({}) {|h,f|
        (h[f.scan_class] ||= []) << f
        h
      }
    end
  end
end


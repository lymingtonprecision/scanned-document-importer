require File.join(File.dirname(__FILE__), "..", "ifs")

module IFS
  class ImportJob
    class << self
      def run_job(dry_run=false, &block)
        IFS.connect(&block)
      end

      def perform(dry_run=false, *obj_classes)
        log_file = if dry_run
                     STDOUT
                   else
                     IFS::Logger.file_path(IFS.config["scanbasedir"])
                   end
        log = IFS::Logger.new(log_file)
        docs = 0

        log.info { "starting import of #{obj_classes}" }

        if dry_run
          log.info { "Performing a DRY RUN - no files will be changed or records created"}
        end

        run_job(dry_run) do
          log.info { "connected to #{IFS.default_credentials[:instance]}" }

          begin
            obj_classes.each do |obj_class|
              klass_docs = 0

              if IFS.const_defined? obj_class
                log.info { "starting import of #{obj_class}"}
                klass = IFS.const_get(obj_class)
                klass_docs = klass.process_new_documents(dry_run)
                log.info { "finished import of #{obj_class} (#{klass_docs} documents imported)"}
              else
                log.error { "don't know how to import '#{obj_class}' documents"}
              end

              docs += klass_docs
            end

            log.info { "all document types processed, #{docs} documents imported" }

            IFS.rollback if dry_run || docs == 0
          rescue
            log.fatal $!
          ensure
            log.close
          end
        end
      end
    end
  end
end

require 'securerandom'
require File.join(File.dirname(__FILE__), "..", "ifs")

module IFS
  class ImportJob
    class << self
      def perform(*obj_classes)
        log = IFS::Object.logger
        run_id = SecureRandom.uuid
        docs = 0

        IFS.connect do
          begin
            if log.nil?
              log = IFS::Logger.new
              IFS::Object.set_logger log
            end

            log.start run_id

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
    end
  end
end

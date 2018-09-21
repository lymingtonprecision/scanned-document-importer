module IFS
  class Object
    class << self
      def find
        nil
      end

      def find_new_files
        files = []

        Dir.glob(File.join(scanning_dir, "*.pdf")) do |fp|
          file = ScannedFile.new(fp)
          block_given? ? yield(file) : (files << file)
        end

        return block_given? ? nil : files
      end

      def class_name
        self.name[/::([^:]+)$/, 1]
      end

      def parent_class_value(attr)
        parent_class = ancestors.find {|c|
          next if c == self
          c.respond_to?(attr) && !c.send(attr).nil?
        }

        parent_class.nil? ? nil : parent_class.send(attr)
      end

      def set_doc_class(doc_class)
        @doc_class = doc_class
      end

      def doc_class
        @doc_class.nil? ? parent_class_value(:doc_class) : @doc_class
      end

      def set_lu_name(lu_name)
        @lu_name = lu_name
      end

      def lu_name
        @lu_name.nil? ? parent_class_value(:lu_name) : @lu_name
      end

      def set_scanning_base_dir(base_dir)
        @scanning_base_dir = base_dir
      end

      def scanning_base_dir
        if @scanning_base_dir.nil?
          parent_class_value(:scanning_base_dir)
        else
          @scanning_base_dir
        end
      end

      def set_scanning_dir(dir)
        @scanning_dir = dir
      end

      def scanning_dir
        @scanning_dir ||= File.join(
          scanning_base_dir,
          class_name.gsub(/(.)([A-Z])/, '\1_\2').downcase + "s",
          "processed"
        )
      end

      def set_attached_dir(dir)
        @attached_dir = dir
      end

      def attached_dir
        @attached_dir ||= File.join(scanning_dir, "attached")
      end

      def process_new_documents(dry_run=false, base_log)
        doc_count = 0

        log_file = IFS::Logger.file_path(scanning_dir) unless dry_run

        log = if log_file && base_log
                IFS::Logger.new(log_file, base_log)
              elsif log_file
                IFS::Logger.new(log_file)
              elsif base_log
                base_log
              else
                IFS::Logger.new(STDOUT)
              end

        log.info { "checking #{scanning_dir} for files to import"}

        find_new_files do |f|
          log.info { "found #{f.path}, processing" }

          begin
            obj = find(*f.name.split("-"))
          rescue
            log.error { "error looking up associated object" }
            log.error { $! }
            next
          end

          if obj.nil?
            log.warn { "skipping file, #{f.name}, no associated object found" }
          else
            objs = [obj].flatten

            doc = nil
            err = nil

            begin
              begin
                doc = IFS::Document.new(objs[0].doc_class, objs[0].to_s)
                doc.save! unless dry_run
                log.info { "created document #{doc.to_s}" }
              rescue
                log.error { "failed to create document #{doc.to_s}"}
                throw $!
              end

              %w{ORIGINAL VIEW}.each do |dt|
                begin
                  edm_file = IFS::EdmFile.new(
                    doc, dt, objs[0].to_s, f.type, f.to_blob
                  )
                  edm_file.save! unless dry_run
                  doc.files << edm_file
                  log.info { "uploaded scan as #{dt} file of document #{doc.to_s}" }
                rescue
                  log.error { "failed to create #{dt} file for document #{doc.to_s}" }
                  throw $!
                end
              end

              log.info { "connecting document to associated objects" }

              objs.each do |obj|
                begin
                  doc.connect_to(obj) unless dry_run
                  log.info { "connected #{obj.to_s} to document #{doc.to_s}" }
                rescue
                  log.error { "failed to connect #{obj.to_s} to document #{doc.to_s}" }
                  throw $!
                end
              end

              log.info { "finished processing #{f.path}" }

              begin
                d = objs[0].class.attached_dir
                f.move_to(d) unless dry_run
                log.info { "moved #{f.path} to #{d}" }
              rescue
                log.error { "failed to archive file - #{f.path} - after processing" }
                throw $!
              end

              M.database.commit unless dry_run
              doc_count += 1
            rescue
              log.error { $!}
            end
          end
        end

        return doc_count
      end
    end

    def doc_class
      self.class.doc_class
    end

    def lu_name
      self.class.lu_name
    end

    def key_ref
      keys.collect {|kv| "#{kv.keys[0]}=#{kv.values[0]}"}.join("^") + "^"
    end

    def key_value
      keys.collect {|kv| kv.values[0]}.join("^") + "^"
    end

    def keys
      []
    end

    def to_s
      key_value.gsub(/\^/, "-")
    end
  end
end

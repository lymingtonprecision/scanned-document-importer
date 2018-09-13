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

      def set_logger(log)
        @logger = log
      end

      def logger
        @logger.nil? ? parent_class_value(:logger) : @logger
      end

      def log(meth, *args)
        return if logger.nil?
        logger.send(meth, *args)
      end

      def process_new_documents(log_id=nil)
        log :doc_class, log_id, class_name, scanning_dir
        doc_count = 0
        find_new_files do |f|
          begin
            obj = find(*f.name.split("-"))
          rescue
            log :doc_file, log_id, class_name, f.path, doc_class, nil, nil, nil, $!
            next
          end

          if obj.nil?
            log :doc_file, log_id, class_name, f.path, doc_class, nil, nil, nil, "can't find associated object (#{f.name})"
          else
            objs = [obj].flatten

            doc = nil
            err = nil

            begin
              doc = IFS::Document.new(objs[0].doc_class, objs[0].to_s)

              %w{ORIGINAL VIEW}.each do |dt|
                doc.files << IFS::EdmFile.new(
                  doc, dt, objs[0].to_s, f.type, f.to_blob
                )
              end

              objs.each do |obj|
                doc.connect_to(obj)

                log(
                  :doc_file,
                  log_id,
                  class_name,
                  f.path,
                  doc_class,
                  doc.nil? ? nil : doc.no,
                  obj.lu_name,
                  obj.key_ref,
                  err
                )
              end

              f.move_to objs[0].class.attached_dir
              M.database.commit
              doc_count += 1
            rescue
              err = $!

              log(
                :doc_file,
                log_id,
                class_name,
                f.path,
                doc_class,
                doc.nil? ? nil : doc.no,
                objs[0].lu_name,
                objs[0].key_ref,
                err
              )
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

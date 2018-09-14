module IFS; end

class IFS::Logger
  def initialize
    # noop
  end

  def close
    # noop
  end

  #
  # Logging methods
  #
  def start
    # TODO write a 'started' entry to the log?
  end

  def error_to_s(error)
    error_text = ""

    if error.kind_of? StandardError
      error_text = "#{error.class}: #{error.message}\n"
      error_text << error.backtrace.map {|l| "\t#{l}" }.join("\n")
    else
      error_text = error.to_s
    end

    return error_text
  end

  def error(run_id, error)
    # TODO write the error to the log?
  end

  def finish(run_id)
    # TODO write a 'finished' entry to the log?
  end

  def doc_class(run_id, doc_class, dir)
    # TODO write a 'processing <doc_class>' entry to the log
  end

  def doc_file(
    run_id,
    doc_class,
    file_path,
    doc_class_no,
    doc_no=nil,
    obj_lu=nil,
    obj_key=nil,
    error=nil
  )
    # TODO write a 'processed <file details>' entry to the log
  end
end

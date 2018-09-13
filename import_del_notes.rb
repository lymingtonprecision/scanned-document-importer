require File.join(File.dirname(__FILE__), "lib", "scan_import", "ifs", "import_job")

if __FILE__ == $0
  IFS.load_config

  IFS::ImportJob.perform("CustOrdPickList")
end


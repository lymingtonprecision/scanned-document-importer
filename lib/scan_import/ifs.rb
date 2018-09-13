require "pathname"
require "oci8"
require File.join(File.dirname(__FILE__), "logger")
require File.join(File.dirname(__FILE__), "ifs", "object")
require File.join(File.dirname(__FILE__), "ifs", "document")
require File.join(File.dirname(__FILE__), "ifs", "edm_file")
require File.join(File.dirname(__FILE__), "ifs", "scanned_file")

Dir.glob(File.join(File.dirname(__FILE__), "ifs", "objects", "*.rb")) do |f|
  require f
end

module IFS
  class << self
    def set_default_credentials(instance, user=nil, password=nil)
      if instance.kind_of?(Hash) && user.nil? && password.nil?
        user ||= instance[:username] || instance[:user]
        password ||= instance[:password] || instance[:pwd]
        instance = instance[:instance] || instance[:database]
      end

      @default_credentials = {
        :instance => instance,
        :username => user,
        :password => password
      }
    end

    def default_credentials
      @default_credentials || {}
    end

    def connect(instance=nil, username=nil, password=nil)
      instance ||= default_credentials[:instance]
      username ||= default_credentials[:username]
      password ||= default_credentials[:password]

      disconnect
      @database = OCI8.new(username, password, instance)

      if block_given?
        begin
          yield self
          commit
        ensure
          rollback
          disconnect
        end
      end
    end

    def database
      block_given? ? yield(@database) : @database
    end

    def commit
      database.commit unless database.nil?
    end

    def rollback
      database.rollback unless database.nil?
    end

    def disconnect
      database.logoff unless database.nil?
    end

    def load_config(config_path=nil, base_dir=nil, env=nil)
      base_dir = File.dirname(base_dir || $0)
      config_path ||= File.join(base_dir, "config.yml")
      env ||= ENV["RACK_ENV"] || ENV["RAILS_ENV"] || :development

      @config = YAML.load_file(config_path)[env.to_s.downcase]

      %w{scanbasedir}.each do |path|
        pn = Pathname.new(@config[path])

        if pn.relative?
          @config[path] = File.join(File.dirname(config_path), @config[path])
        end
      end

      set_default_credentials(
        :instance => @config["instance"],
        :username => @config["username"],
        :password => @config["password"]
      )

      ::IFS::Object.set_scanning_base_dir @config["scanbasedir"]

      return config
    end

    def config
      @config
    end
  end

  M = self
end


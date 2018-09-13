require "sqlite3"

class Logger
  class << self
    def set_default_path(path)
      @default_path = path
    end

    def default_path
      @default_path
    end

    def tables
      @tables ||= {}
    end

    def sanitize_table_name(name)
      name.to_s.strip.downcase
    end

    def col_to_sql(col_def)
      col_type = "TEXT"

      if col_def[1] == Float
        col_type = "REAL"
      elsif col_def[1] == Fixnum
        col_type = "INTEGER"
      end

      constraints = ["NOT NULL"]

      if col_def[-1].kind_of? Hash
        constraints.delete_at(0) if col_def[-1][:null] == true

        if col_def[-1].include? :primary_key
          if col_def[-1].include? :autoincrement
            constraints.unshift("PRIMARY KEY AUTOINCREMENT")
          else
            constraints.unshift("PRIMARY KEY")
          end
        end

        constraints << "UNIQUE" if col_def[-1][:unique] == true

        if col_def[-1].include? :default
          constraints.unshift("DEFAULT '#{col_def[-1][:default]}'")
        end
      end

      "#{col_def[0].to_s.upcase} #{col_type} #{constraints.join(" ")}"
    end

    def define_table(name, columns, attrs={})
      name = sanitize_table_name(name)

      return if tables.include?(name)

      constraints = []

      create_sql = <<-SQL
        CREATE TABLE IF NOT EXISTS #{name} (
          #{columns.collect {|c| col_to_sql(c)}.join(",")}
          #{", #{constraints.join(",")}" unless constraints.empty?}
        );
      SQL

      insert_sql = <<-SQL
        INSERT INTO #{name} VALUES (
          #{columns.collect {|c| ":#{c[0]}"}.join(",")}
        );
      SQL

      tables[name] = attrs.merge(
        :name => name,
        :columns => columns,
        :create => create_sql,
        :insert => insert_sql
      )
    end
  end

  define_table(
    "runs",
    [
      [:id, Fixnum, {:primary_key => true, :autoincrement => true}],
      [:start, Fixnum],
      [:finish, Fixnum, {:null => true}],
      [:error, String, {:null => true}]
    ]
  )

  define_table(
    "run_classes",
    [
      [:run_id, Fixnum],
      [:class_name, String],
      [:directory, String]
    ]
  )

  define_table(
    "run_files",
    [
      [:run_id, Fixnum],
      [:class_name, String],
      [:filename, String],
      [:processed_at, Fixnum],
      [:doc_class, Fixnum, {:null => true}],
      [:doc_no, Fixnum, {:null => true}],
      [:object_lu, String, {:null => true}],
      [:object_key_ref, String, {:null => true}],
      [:error, String, {:null => true}]
    ]
  )

  attr_reader :db

  def initialize(db_file=self.class.default_path)
    @db = SQLite3::Database.new(db_file)

    create_all_tables!
  end

  def close
    @db.close
  end

  def tables
    self.class.tables
  end

  def table_exists?(table)
    (db.get_first_value(<<-SQL, "name" => table
      select count(*)
      from sqlite_master
      where type='table'
        and name=:name
      SQL
    ) || 0) == 1
  end

  def create_all_tables!
    tables.keys.each {|table| create_table! table}
  end

  def create_table!(table)
    return if table_exists?(table)
    db.execute(tables[table][:create])
  end

  #
  # Logging methods
  #
  def start
    db.execute(
      tables["runs"][:insert],
      nil,
      Time.now.to_i,
      nil,
      nil
    )

    @run_id = nil

    return last_run_id
  end

  def last_run_id
    @run_id ||= db.last_insert_row_id
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
    run_id ||= last_run_id

    db.execute(<<-SQL, error_to_s(error), Time.now.to_i, run_id
      update runs
      set error = :error,
        finish = :finish
      where id = :run_id
      SQL
    )
  end

  def finish(run_id=last_run_id)
    db.execute(<<-SQL, Time.now.to_i, run_id
      update runs
      set finish = :finish
      where id = :run_id
      SQL
    )
  end

  def doc_class(run_id, doc_class, dir)
    run_id ||= last_run_id
    db.execute(tables["run_classes"][:insert], run_id, doc_class, dir)
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
    run_id ||= last_run_id
    db.execute(
      tables["run_files"][:insert],
      run_id,
      doc_class,
      File.expand_path(file_path),
      Time.now.to_i,
      doc_class_no,
      doc_no,
      obj_lu,
      obj_key,
      error_to_s(error)
    )
  end
end


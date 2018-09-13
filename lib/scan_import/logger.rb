module IFS; end

class IFS::Logger
  TBL_PREFIX = "scan_import"

  DEFAULT_TABLE_PARAMS = <<-TXT
    PCTFREE 10 PCTUSED 40 INITRANS 1 MAXTRANS 255 NOCOMPRESS LOGGING
    STORAGE (
      INITIAL         106496
      NEXT            1048576
      MINEXTENTS      1
      MAXEXTENTS      2147483645
      PCTINCREASE     0
      FREELISTS       1
      FREELIST GROUPS 1
      BUFFER_POOL     DEFAULT
    )
  TXT

  class << self
    def tables
      @tables ||= {}
    end

    def sanitize_table_name(name)
      name.to_s.strip.downcase
    end

    def col_to_sql(col_def)
      col_type = "NUMBER"

      if col_def[1].ancestors.include?(Numeric) && col_def[2].kind_of?(Numeric)
        if col_def[3].kind_of?(Numeric)
          col_type = "NUMBER(#{col_def[2]}, #{col_def[3]})"
        else
          col_type = "NUMBER(#{col_def[2]})"
        end
      elsif col_def[1] == String
        if col_def[2] > 4000
          col_type = "CLOB"
        else
          col_type = "VARCHAR2(#{col_def[2]})"
        end
      elsif col_def[1] == Time
        col_type = "TIMESTAMP(0)"
      elsif col_def[1] == Date
        col_type = "DATE"
      end

      constraints = ["NOT NULL"]

      if col_def[-1].kind_of? Hash
        constraints.delete_at(0) if col_def[-1][:null] == true

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

      unless attrs[:primary_key].nil?
        constraints << "CONSTRAINT #{name}_pk " +
          "PRIMARY KEY (#{attrs[:primary_key].join(", ")})"
      end

      create_sql = <<-SQL
        CREATE TABLE #{name} (
          #{columns.collect {|c| col_to_sql(c)}.join(",")}
          #{", #{constraints.join(",")}" unless constraints.empty?}
        ) #{DEFAULT_TABLE_PARAMS}
      SQL

      insert_sql = <<-SQL
        INSERT INTO #{name} VALUES (
          #{columns.collect {|c| ":#{c[0]}"}.join(",")}
        )
      SQL

      tables[name] = attrs.merge(
        :name => name,
        :columns => columns,
        :create => create_sql,
        :insert => insert_sql
      )
    end

    def table_exists?(table)
      table_name = sanitize_table_name(table)

      result = IFS.database {|d|
        d.exec(<<-SQL, table_name.to_s.upcase
          select count(*)
          from user_tables
          where table_name = :table_name
          SQL
        ).fetch
      }

      return result[0] > 0
    end

    def create_all_tables!
      tables.keys.each {|table| create_table! table}
    end

    def create_table!(table)
      return unless tables.include?(table)
      return if table_exists?(table)

      IFS.database {|d|
        d.exec(tables[table][:create])
        tables[table][:on_create].call(d) unless tables[table][:on_create].nil?
        d.commit
      }
    end

    def drop_all_tables!
      tables.keys.each {|table| drop_table! table}
    end

    def drop_table!(table)
      return unless tables.include?(table)
      return unless table_exists?(table)

      IFS.database {|d|
        tables[table][:on_drop].call(d) unless tables[table][:on_drop].nil?
        d.exec("drop table #{table}")
        d.commit
      }
    end
  end

  define_table(
    "#{TBL_PREFIX}_runs",
    [
      [:run_id, Fixnum],
      [:started_at, Time],
      [:finished_at, Time, {:null => true}],
      [:error, String, 4000, {:null => true}]
    ],
    :primary_key => [:run_id],
    :on_create => lambda {|db|
      db.exec("create sequence #{TBL_PREFIX}_runs_id_seq start with 81")
      db.exec(<<-SQL
        create or replace trigger #{TBL_PREFIX}_runs_auto_id
          before insert on #{TBL_PREFIX}_runs
          for each row
        begin
          select #{TBL_PREFIX}_runs_id_seq.nextval into :new.run_id from dual;
        end;
        SQL
      )
    },
    :on_drop => lambda {|db|
      db.exec(<<-SQL
        declare
          exists_ number := 0;
        begin
          select count(*)
          into exists_
          from user_triggers
          where upper(trigger_name) = upper('#{TBL_PREFIX}_runs_auto_id')
          ;

          if exists_ > 0 then
            execute immediate ('drop trigger #{TBL_PREFIX}_runs_auto_id');
          end if;

          exists_ := 0;

          select count(*)
          into exists_
          from user_sequences
          where upper(sequence_name) = upper('#{TBL_PREFIX}_runs_id_seq')
          ;

          if exists_ > 0 then
            execute immediate ('drop sequence #{TBL_PREFIX}_runs_id_seq');
          end if;
        end;
        SQL
      )
    }
  )

  define_table(
    "#{TBL_PREFIX}_run_classes",
    [
      [:run_id, Fixnum],
      [:class_name, String, 200],
      [:directory, String, 800]
    ]
  )

  define_table(
    "#{TBL_PREFIX}_run_files",
    [
      [:run_id, Fixnum],
      [:class_name, String, 200],
      [:filename, String, 1000],
      [:processed_at, Time],
      [:doc_class, Fixnum, {:null => true}],
      [:doc_no, Fixnum, {:null => true}],
      [:object_lu, String, 254, {:null => true}],
      [:object_key_ref, String, 254, {:null => true}],
      [:error, String, 4000, {:null => true}]
    ]
  )

  def initialize
    self.class.create_all_tables!
  end

  def close
    # noop
  end

  def tables
    self.class.tables
  end

  #
  # Logging methods
  #
  def start
    tbl = tables["#{TBL_PREFIX}_runs"]

    IFS.database {|db|
      c = db.parse(tbl[:insert])
      c.bind_param(':run_id', nil, Fixnum)
      c.bind_param(':started_at', Time.now, Time)
      c.bind_param(':finished_at', nil, Time)
      c.bind_param(':error', nil, String, 4000)
      c.exec

      ri = db.exec(<<-SQL, c.rowid
        select
          run_id
        from #{tbl[:name]}
        where rowid = :inserted_row
        SQL
      )

      @run_id = ri.fetch[0].to_i
    }

    return last_run_id
  end

  def last_run_id
    @run_id
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

    IFS.database {|db|
      c = db.parse(<<-SQL
        update #{tables["#{TBL_PREFIX}_runs"][:name]}
        set error = :error, finished_at = sysdate
        where run_id = :run_id
        SQL
      )
      c.bind_param(':run_id', run_id, Fixnum)
      c.bind_param(':error', error.to_s[0, 4000], String, 4000)
      c.exec
    }
  end

  def finish(run_id=last_run_id)
    IFS.database {|db|
      c = db.parse(<<-SQL
        update #{tables["#{TBL_PREFIX}_runs"][:name]}
        set finished_at = :finished_at
        where run_id = :run_id
        SQL
      )
      c.bind_param(':run_id', run_id, Fixnum)
      c.bind_param(':finished_at', Time.now, Time)
      c.exec
    }
  end

  def doc_class(run_id, doc_class, dir)
    run_id ||= last_run_id

    IFS.database {|db|
      c = db.parse(tables["#{TBL_PREFIX}_run_classes"][:insert])
      c.bind_param(':run_id', run_id, Fixnum)
      c.bind_param(':class_name', doc_class.to_s[0, 200], String, 200)
      c.bind_param(':directory', dir.to_s[0, 800], String, 800)
      c.exec
    }
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

    IFS.database {|db|
      c = db.parse(tables["#{TBL_PREFIX}_run_files"][:insert])
      c.bind_param(':run_id', run_id, Fixnum)
      c.bind_param(':class_name', doc_class.to_s[0, 200], String, 200)
      c.bind_param(':filename', file_path.to_s[0, 1000], String, 1000)
      c.bind_param(':processed_at', Time.now, Time)
      c.bind_param(':doc_class', doc_class_no.to_i, Fixnum)
      c.bind_param(':doc_no', doc_no.nil? ? nil : doc_no.to_i, Fixnum)
      c.bind_param(':object_lu', obj_lu.to_s[0, 254], String, 254)
      c.bind_param(':object_key_ref', obj_key.to_s[0, 254], String, 254)
      c.bind_param(':error', error.to_s[0, 4000], String, 4000)
      c.exec
    }
  end
end


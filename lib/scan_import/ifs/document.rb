module IFS
  class Document
    attr_reader :doc_class, :no, :title
    attr_reader :sheet, :rev
    attr_reader :objects

    def initialize(doc_class, title, no=nil, sheet=1, rev="A1")
      @doc_class = doc_class
      @title = title
      @no = no
      @sheet = sheet
      @rev = rev
      @objects = []
    end

    def to_s
      "{class: #{doc_class}, title: #{title}, number: #{no}, sheet: #{sheet}, rev: #{rev}}"
    end

    def save!
      save = M.database.parse(<<-SQL
        declare
          info_ varchar2(32000);
          objid_ varchar2(32000);
          objver_ varchar2(32000);
          attr_ varchar2(32000);
        begin
          ifsapp.Client_SYS.Clear_Attr(attr_);

          ifsapp.doc_title_api.new__(info_, objid_, objver_, attr_, 'PREPARE');

          ifsapp.Client_SYS.Add_to_Attr('DOC_CLASS', :doc_class, attr_);
          ifsapp.Client_SYS.Add_to_Attr('TITLE', :title, attr_);
          ifsapp.Client_SYS.Add_to_Attr('VIEW_FILE_REQ', 'Optional', attr_);
          ifsapp.Client_SYS.Add_to_Attr('OBJ_CONN_REQ', 'Required', attr_);
          ifsapp.Client_SYS.Add_to_Attr('MAKE_WASTE_REQ', 'No', attr_);
          ifsapp.Client_SYS.Add_to_Attr('SAFETY_COPY_REQ', 'No', attr_);

          ifsapp.doc_title_api.new__(info_, objid_, objver_, attr_, 'DO');

          :doc_no := ifsapp.Client_SYS.Get_Item_Value('DOC_NO', attr_);
        end;
        SQL
      )

      begin
        save.bind_param(':doc_class', doc_class, String, 12)
        save.bind_param(':title', title, String, 250)
        save.bind_param(':doc_no', nil, String, 120)
        save.exec

        @no = save[':doc_no']
      ensure
        save.close
      end
    end

    def connect_to(obj)
      Connection.create(self, obj)
      objects << obj
      return self
    end
  end

  class Document::Connection
    def self.create(doc, obj)
      connect = M.database.parse(<<-SQL
        declare
          info_ varchar2(32000);
          objid_ varchar2(32000);
          objver_ varchar2(32000);
          attr_ varchar2(32000);
        begin
          ifsapp.Client_SYS.Clear_Attr(attr_);

          ifsapp.Client_SYS.Add_to_Attr('LU_NAME', :lu_name, attr_);
          ifsapp.Client_SYS.Add_to_Attr('KEY_REF', :key_ref, attr_);
          ifsapp.Client_SYS.Add_to_Attr('DOC_CLASS', :doc_class, attr_);
          ifsapp.Client_SYS.Add_to_Attr('DOC_NO', :doc_no, attr_);
          ifsapp.Client_SYS.Add_to_Attr('DOC_SHEET', :doc_sheet, attr_);
          ifsapp.Client_SYS.Add_to_Attr('DOC_REV', :doc_rev, attr_);
          ifsapp.Client_SYS.Add_to_Attr('KEEP_LAST_DOC_REV', 'Fixed', attr_);
          ifsapp.Client_SYS.Add_to_Attr('COPY_FLAG', 'OK', attr_);
          ifsapp.Client_SYS.Add_to_Attr('SURVEY_LOCKED_FLAG', 'Unlocked', attr_);

          ifsapp.doc_reference_object_api.new__(
            info_, objid_, objver_, attr_, 'DO'
          );
        end;
        SQL
      )

      begin
        connect.bind_param(':lu_name', obj.class.lu_name, String, 30)
        connect.bind_param(':key_ref', obj.key_ref, String, 500)
        connect.bind_param(':doc_class', doc.doc_class, String, 12)
        connect.bind_param(':doc_no', doc.no, String, 120)
        connect.bind_param(':doc_sheet', doc.sheet.to_s, String, 10)
        connect.bind_param(':doc_rev', doc.rev, String, 6)

        connect.exec
      ensure
        connect.close
      end
    end
  end
end


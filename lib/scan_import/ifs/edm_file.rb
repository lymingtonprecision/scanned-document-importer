module IFS
  class EdmFile
    attr_reader :document, :doc_type
    attr_reader :no, :name, :type, :location, :contents

    def self.exists?(doc, doc_type, file_no)
      find = M.database.parse(<<-SQL
        select
          count(*)
        from ifsapp.edm_file ef
        where ef.doc_class = :doc_class
          and ef.doc_no = :doc_no
          and ef.doc_sheet = :doc_sheet
          and ef.doc_rev = :doc_rev
          and ef.doc_type = :doc_type
          and ef.file_no = :file_no
        SQL
      )

      result = 0

      begin
        find.bind_param(':doc_class', doc.doc_class, String, 12)
        find.bind_param(':doc_no', doc.no, String, 120)
        find.bind_param(':doc_sheet', doc.sheet.to_s, String, 10)
        find.bind_param(':doc_rev', doc.rev, String, 6)
        find.bind_param(':doc_type', doc_type, String, 12)
        find.bind_param(':file_no', file_no, Integer)

        find.exec

        result = (find.fetch || [])[0] || 0
      ensure
        find.close
      end

      return result == 1
    end

    def initialize(document, doc_type, name, type, contents=nil, no=1)
      @document = document
      @doc_type = doc_type
      @name = name
      @type = type
      @no = no
      @contents = contents
      @location = "IFS_DB"
    end

    def exists?
      self.class.exists?(document, doc_type, no)
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

          ifsapp.edm_file_api.new__(info_, objid_, objver_, attr_, 'PREPARE');

          ifsapp.Client_SYS.Add_to_Attr('DOC_CLASS', :doc_class, attr_);
          ifsapp.Client_SYS.Add_to_Attr('DOC_NO', :doc_no, attr_);
          ifsapp.Client_SYS.Add_to_Attr('DOC_SHEET', :doc_sheet, attr_);
          ifsapp.Client_SYS.Add_to_Attr('DOC_REV', :doc_rev, attr_);
          ifsapp.Client_SYS.Add_to_Attr('DOC_TYPE', :doc_type, attr_);
          ifsapp.Client_SYS.Add_to_Attr('FILE_NO', :file_no, attr_);
          ifsapp.Client_SYS.Add_to_Attr('FILE_NAME', :file_name, attr_);
          ifsapp.Client_SYS.Add_to_Attr('FILE_TYPE', :file_type, attr_);
          ifsapp.Client_SYS.Add_to_Attr('LOCATION_NAME', :file_loc, attr_);

          ifsapp.Client_SYS.Add_to_Attr('CHECKED_IN_SIGN', user, attr_);
          ifsapp.Client_SYS.Add_to_Attr('CHECKED_IN_DATE', sysdate, attr_);
          ifsapp.Client_SYS.Add_to_Attr('CHECKED_OUT_SIGN', user, attr_);
          ifsapp.Client_SYS.Add_to_Attr('CHECKED_OUT_DATE', sysdate, attr_);

          ifsapp.edm_file_api.new__(info_, objid_, objver_, attr_, 'DO');

          ifsapp.Client_SYS.Clear_Attr(attr_);

          ifsapp.edm_file_storage_api.new__(info_, objid_, objver_, attr_, 'PREPARE');

          ifsapp.Client_SYS.Add_to_Attr('DOC_CLASS', :doc_class, attr_);
          ifsapp.Client_SYS.Add_to_Attr('DOC_NO', :doc_no, attr_);
          ifsapp.Client_SYS.Add_to_Attr('DOC_SHEET', :doc_sheet, attr_);
          ifsapp.Client_SYS.Add_to_Attr('DOC_REV', :doc_rev, attr_);
          ifsapp.Client_SYS.Add_to_Attr('DOC_TYPE', :doc_type, attr_);
          ifsapp.Client_SYS.Add_to_Attr('FILE_NO', :file_no, attr_);

          ifsapp.edm_file_storage_api.new__(info_, objid_, objver_, attr_, 'DO');

          ifsapp.edm_file_storage_api.write_blob_data(
            objver_, objid_, :data
          );
        end;
        SQL
      )

      begin
        data = OCI8::BLOB.new(M.database, contents)

        save.bind_param(':doc_class', document.doc_class, String, 12)
        save.bind_param(':doc_no', document.no, String, 120)
        save.bind_param(':doc_sheet', document.sheet.to_s, String, 10)
        save.bind_param(':doc_rev', document.rev, String, 6)
        save.bind_param(':doc_type', doc_type, String, 12)
        save.bind_param(':file_no', no, Integer)
        save.bind_param(':file_name', name, String, 254)
        save.bind_param(':file_type', type, String, 30)
        save.bind_param(':file_loc', location, String, 254)
        save.bind_param(':data', data)

        save.exec
      ensure
        save.close
      end
    end
  end
end


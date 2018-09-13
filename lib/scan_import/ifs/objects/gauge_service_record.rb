require File.join(File.dirname(__FILE__), "..", "object")

module IFS
  class GaugeServiceRecord < Object
    set_doc_class "550"
    set_lu_name "EquipmentObject"

    attr_reader :object_id

    def self.find(object_id)
      find = M.database.parse(<<-SQL
        select
          es.mch_code
        from ifsapp.equipment_serial es
        where es.contract = 'LPE'
          and replace(es.mch_code, ' ', '') like replace(:serial_no, ' ', '')
        SQL
      )

      find.bind_param(':serial_no', object_id, String, 100)

      find.exec
      result = find.fetch
      find.close

      if result && result[0]
        self.new(result[0])
      else
        return nil
      end
    end

    def initialize(object_id)
      @object_id = object_id
    end

    def keys
      [
        {"CONTRACT" => "LPE"},
        {"MCH_CODE" => object_id}
      ]
    end

    def to_s
      "#{object_id} Archive"
    end
  end
end

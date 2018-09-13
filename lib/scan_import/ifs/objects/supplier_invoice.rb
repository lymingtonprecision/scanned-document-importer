require File.join(File.dirname(__FILE__), "..", "object")

module IFS
  class SupplierInvoice < Object
    set_doc_class "330"
    set_lu_name "ManSuppInvoice"

    attr_reader :company, :id, :payment_reference

    def self.find(payment_reference)
      payment_reference.gsub! /^330_/, ''

      find = M.database.parse(<<-SQL
        select
          i.company,
          i.invoice_id,
          i.ncf_reference
        from ifsapp.invoice_tab i
        where i.party_type = 'SUPPLIER'
          and i.creator = 'MAN_SUPP_INVOICE_API'
          and i.rowstate <> 'Cancelled'
          and i.ncf_reference = :payment_ref
        SQL
      )

      find.bind_param(':payment_ref', payment_reference, String, 50)

      find.exec
      result = find.fetch
      find.close

      if result.nil? || result.empty?
        return nil
      else
        self.new(*result)
      end
    end

    def initialize(company, id, payment_reference)
      @company = company
      @id = id
      @payment_reference = payment_reference
    end

    def keys
      [
        {"COMPANY" => company},
        {"INVOICE_ID" => id}
      ]
    end

    def to_s
      "Supplier Invoice #{payment_reference}"
    end

    def self.obj_ref(keys)
      "Supplier Invoice ID #{keys["INVOICE_ID"]}"
    end

    def self.obj_url(keys)
      "#{BASE_URL}ifsapf%3AfrmManualSupplierInvoice%3Faction%3Dget%26key1%3D#{keys["COMPANY"]}%255E#{keys["INVOICE_ID"]}%26COMPANY%3DLPE"
    end
  end
end


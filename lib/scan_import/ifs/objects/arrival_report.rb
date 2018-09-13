require File.join(File.dirname(__FILE__), "..", "object")

module IFS
  class ArrivalReport < Object
    set_doc_class "240"
    set_lu_name "PurchaseReceipt"

    attr_reader :order, :line, :release, :receipt

    def self.find(order, line, release, receipt)
      receipt = receipt.to_i

      find = M.database.parse(<<-SQL
        select
          count(*)
        from ifsapp.purchase_receipt pr
        where pr.order_no = :order_no
          and pr.line_no = :line_no
          and pr.release_no = :release_no
          and pr.receipt_no = :receipt_no
        SQL
      )

      find.bind_param(':order_no', order, String, 12)
      find.bind_param(':line_no', line, String, 4)
      find.bind_param(':release_no', release, String, 4)
      find.bind_param(':receipt_no', receipt, Fixnum)

      find.exec
      result = (find.fetch || [])[0] || 0
      find.close

      if result == 1
        self.new(order, line, release, receipt)
      else
        return nil
      end
    end

    def initialize(order, line, release, receipt)
      @order = order
      @line = line
      @release = release
      @receipt = receipt
    end

    def keys
      [
        {"LINE_NO" => line},
        {"ORDER_NO" => order},
        {"RECEIPT_NO" => receipt},
        {"RELEASE_NO" => release}
      ]
    end

    def to_s
      "ARN #{[order, line, release, receipt].join("-")}"
    end

    def self.obj_ref(keys)
      "Order #{keys["ORDER_NO"]}, Line #{keys["LINE_NO"]}, Release #{keys["RELEASE_NO"]}, Receipt #{keys["RECEIPT_NO"]}"
    end

    def self.obj_url(keys)
      "#{BASE_URL}ifsapf%3AfrmPurchaseReceipt%3Faction%3Dget%26key1%3D#{keys["LINE_NO"]}%255E#{keys["ORDER_NO"]}%255E#{keys["RECEIPT_NO"]}%255E#{keys["RELEASE_NO"]}%26COMPANY%3DLPE"
    end
  end
end


require File.join(File.dirname(__FILE__), "..", "object")

module IFS
  class ShopOrder < Object
    set_doc_class "360"
    set_lu_name "ShopOrd"

    attr_reader :order, :release, :sequence

    def self.find(order, release="*", sequence="*")
      find = M.database.parse(<<-SQL
        select
          count(*)
        from ifsapp.shop_ord so
        where so.order_no = :order_no
          and so.release_no = :release_no
          and so.sequence_no = :sequence_no
        SQL
      )

      find.bind_param(':order_no', order, String, 12)
      find.bind_param(':release_no', release, String, 4)
      find.bind_param(':sequence_no', sequence, String, 4)

      find.exec
      result = (find.fetch || [])[0] || 0
      find.close

      if result == 1
        self.new(order, release, sequence)
      else
        return nil
      end
    end

    def self.find_new_files
      files = []

      Dir.glob(File.join(scanning_dir, "*.pdf")) do |fp|
        name = File.basename(fp).gsub(/\.[^.]+$/, "")

        order = name[/^(RMA|IFR|L)?\d+/]
        rel = name[/\dR(\d+)/, 1] || "*"
        seq = name[/\dS(\d+)/, 1] || "*"

        file = ScannedFile.new(fp, "#{order}-#{rel}-#{seq}")
        block_given? ? yield(file) : (files << file)
      end

      return block_given? ? nil : files
    end

    def initialize(order, release="*", sequence="*")
      @order = order
      @release = release
      @sequence = sequence
    end

    def keys
      [
        {"ORDER_NO" => order},
        {"RELEASE_NO" => release},
        {"SEQUENCE_NO" => sequence}
      ]
    end

    def to_s
      "Shop Order #{order}"
    end
  end
end

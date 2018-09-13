require File.join(File.dirname(__FILE__), "..", "object")

module IFS
  class CustOrdDelNote < Object
    set_doc_class "101"
    set_lu_name "CustomerOrderLine"

    def self.del_note_no?(pick_list_no)
      pick_list_no =~ /^DN \d+$/
    end

    def self.find(pick_list_no)
      lines = []

      find_co_lines = M.database.parse(<<-SQL
        select distinct
          order_no,
          line_no,
          rel_no,
          line_item_no
        from ifsapp.customer_order_delivery
        where delnote_no = :pick_list
        SQL
      )

      find_co_lines.bind_param(
        ':pick_list',
        pick_list_no[/\d+$/],
        String,
        15
      )

      find_co_lines.exec

      while r = find_co_lines.fetch
        lines << CustOrdDelNote.new(pick_list_no, *r)
      end

      find_co_lines.close

      if lines.size > 0
        return lines
      else
        return nil
      end
    end

    attr_reader :pick_list, :order, :line, :release, :item

    def initialize(pick_list, order, line, release, item=0)
      @pick_list = pick_list
      @order = order
      @line = line
      @release = release
      @item = item
    end

    def keys
      [
        {"LINE_ITEM_NO" => item.to_i.to_s},
        {"LINE_NO" => line},
        {"ORDER_NO" => order},
        {"REL_NO" => release}
      ]
    end

    def to_s
      "Del Note #{pick_list[/\d+$/]}"
    end
  end

  class CustOrdPickList < CustOrdDelNote
    set_doc_class "100"

    def self.find(pick_list_no)
      lines = []

      return super(pick_list_no) if del_note_no?(pick_list_no)

      find_co_lines = M.database.parse(<<-SQL
        select distinct
          order_no,
          line_no,
          rel_no,
          line_item_no
        from ifsapp.customer_order_reservation
        where pick_list_no = :pick_list
        SQL
      )

      find_co_lines.bind_param(':pick_list', pick_list_no, String, 15)

      find_co_lines.exec

      while r = find_co_lines.fetch
        lines << self.new(pick_list_no, *r)
      end

      find_co_lines.close

      if lines.size > 0
        return lines
      else
        return nil
      end
    end

    def to_s
      "CofC #{pick_list}"
    end
  end
end

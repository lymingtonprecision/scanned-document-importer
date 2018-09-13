unless OCI8::Cursor.method_defined?(:each)
  class OCI8::Cursor
    def each(&block)
      row = fetch

      while !row.nil?
        yield row
        row = fetch
      end

      close
    end
  end
end

unless OCI8::Cursor.method_defined?(:each_hash)
  class OCI8::Cursor
    def each_hash(&block)
      row = fetch_hash

      while !row.nil?
        yield row
        row = fetch_hash
      end

      close
    end
  end
end

unless OCI8::Cursor.method_defined?(:fetch_all)
  class OCI8::Cursor
    def fetch_all(auto_close=true)
      results = []
      row = fetch

      while !row.nil?
        results << row
        row = fetch
      end

      close if auto_close

      return results
    end
  end
end

unless OCI8::Cursor.method_defined?(:fetch_all_hashes)
  class OCI8::Cursor
    def fetch_all_hashes(auto_close=true)
      results = []
      row = fetch_hash

      while !row.nil?
        results << row
        row = fetch_hash
      end

      close if auto_close

      return results
    end
  end
end

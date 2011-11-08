module LookUpTable
  module ClassMethods
    protected

    # Reads a complete from given block or generic version
    # HACK: some duplicated methods from Class.lut_write_to_cache
    def lut_read_without_cache(lut_key)
      if lut_options(lut_key)[:sql_mode]
        return lut_read_without_cache_sql_mode(lut_key)
      else
        return lut_read_without_cache_no_sql_mode(lut_key)
      end
    end

    # CHECK: somehow long method
    def lut_read_without_cache_sql_mode(lut_key)
      lut   = {}
      block = lut_proc(lut_key)

      self.where(lut_options(lut_key)[:where]).find_in_batches(:batch_size => lut_options(lut_key)[:batch_size]) do |items| #FIXME not DRY here
        items.each do |item|
          if block
            block.call(lut, item)
          else
            lut[item.send(lut_key)] = item.id
          end
        end
      end

      return lut
    end

    # CHECK: ugly method_name
    def lut_read_without_cache_no_sql_mode(lut_key)
      lut   = {}

      block = lut_proc(lut_key)
      block.call(lut)

      return lut
    end

  end
end


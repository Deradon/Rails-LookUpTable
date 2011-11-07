module LookUpTable
  module ClassMethods
    protected

    # Reads a complete from given block or generic version
    # HACK: some duplicated methods from Class.lut_write_to_cache
    def lut_read_without_cache(name)
      if lut_options(name)[:sql_mode]
        return lut_read_without_cache_sql_mode(name)
      else
        return lut_read_without_cache_no_sql_mode(name)
      end
    end

    # HACK: somehow long method
    def lut_read_without_cache_sql_mode(name)
      lut   = {}
      block = lut_proc(name)

      self.where(lut_options(name)[:where]).find_in_batches(:batch_size => lut_options(name)[:batch_size]) do |items| #FIXME not DRY here
        items.each do |item|
          if block
            block.call(lut, item)
          else
            lut[item.send(name)] = item.id
          end
        end
      end

      return lut
    end

    # HACK: ugly method_name
    def lut_read_without_cache_no_sql_mode(name)
      lut   = {}

      block = lut_proc(name)
      block.call(lut)

      return lut
    end

  end
end


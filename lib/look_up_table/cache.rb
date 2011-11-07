module LookUpTable
  module ClassMethods
    protected

    # Cache entry for given LUT exists?
    # TODO: just check if given key exists
    def lut_cache_exists?(name)
      !lut_read_cache_item(name, 0).nil?
    end

    # Reads a complete lut from cache
    # HACK: this still looks ugly somehow
    def lut_read_from_cache(name)
      lut_write_to_cache(name) unless lut_cache_exists?(name)

      i   = 0
      lut = {}

      while item = lut_read_cache_item(name, i)
        # HACK: merge will override existing values
        lut.merge!(item) if item
        i += 1
      end

      return lut
    end

    # Reads a single item of a LookUpTable from Cache
    def lut_read_cache_item(name, item)
      prefix = lut_options(name)[:prefix]
      Rails.cache.read("#{prefix}#{name}/#{item}")
    end

    # Write a LookUpTable into Cache
    def lut_write_to_cache(name)
      if lut_options(name)[:sql_mode]
        count = lut_write_to_cache_sql_mode(name)
      else
        count = lut_write_to_cache_no_sql_mode(name)
      end

      # HACK: Writing a \0 to terminate batch_items
      lut_write_cache_item(name, count, nil)
    end

    # HACK: somehow long method
    def lut_write_to_cache_sql_mode(name)
      batch_count = 0

      self.where(lut_options(name)[:where]).find_in_batches(:batch_size => lut_options(name)[:batch_size]) do |items| #FIXME not DRY here
        lut   = {}
        block = lut_proc(name)

        items.each do |item|
          if block
            block.call(lut, item)
          else
            lut[item.send(name)] = item.id
          end
        end

        self.lut_write_cache_item(name, batch_count, lut)
        batch_count += 1
      end

      batch_count
    end

    # HACK: somehow long method
    def lut_write_to_cache_no_sql_mode(name)
      lut         = {}
      batch_count = 0

      block = lut_proc(name)
      block.call(lut)

      keys = lut.keys

      while
        key_block = keys.slice!(0, lut_options(name)[:batch_size])
        break if key_block.empty?

        lut_block = {}
        key_block.each{|key| lut_block[key] = lut[key]}

        self.lut_write_cache_item(name, batch_count, lut_block)
        batch_count += 1
      end

      batch_count
    end

    # Write a single Item into LookUpTable-Cache
    def lut_write_cache_item(name, lut_item, lut_data)
      prefix = lut_options(name)[:prefix]
      status = Rails.cache.write("#{prefix}#{name}/#{lut_item}", lut_data)
      raise "Cache::write failed - Try lower :batch_size" unless status
    end

  end
end


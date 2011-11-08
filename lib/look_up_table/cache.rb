module LookUpTable
  module ClassMethods
    protected

    # Cache entry for given LUT exists?
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
        # FIXME: merge will override existing values
        # lut.merge!(item) if item
        if item
          item.each do |k,v|
            if lut[k]
              v      = [v]      unless v.respond_to?(:concat)
              lut[k] = [lut[k]] unless lut[k].respond_to?(:concat)
              lut[k].concat(v)
            else
              lut[k] = v
            end
          end
        end

        i += 1
      end

      return lut
    end

    # Write a LookUpTable into Cache
    def lut_write_to_cache(lut_key)
      if lut_options(lut_key)[:sql_mode]
        count = lut_write_to_cache_sql_mode(lut_key)
      else
        count = lut_write_to_cache_no_sql_mode(lut_key)
      end

      # HACK: Writing a \0 to terminate batch_items
      lut_write_cache_item(lut_key, count, nil)
    end

    # HACK: somehow long method
    def lut_write_to_cache_sql_mode(lut_key)
      batch_count = 0

      self.where(lut_options(lut_key)[:where]).find_in_batches(:batch_size => lut_options(lut_key)[:batch_size]) do |items| #FIXME not DRY here
        lut   = {}
        block = lut_proc(lut_key)

        items.each do |item|
          if block
            block.call(lut, item)
          else
            # HACK: doing a merge w/o replacing, just add elements for childs and may transform elements to array
            k = item.send(lut_key)
            v = item.id
            if lut[k]
              v      = [v]      unless v.respond_to?(:concat)
              lut[k] = [lut[k]] unless lut[k].respond_to?(:concat)
              lut[k].concat(v)
            else
              lut[k] = v
            end
          end
        end

        batch_count = self.lut_write_cache_item(lut_key, batch_count, lut)
        batch_count += 1
      end

      batch_count
    end

    # HACK: somehow long method
    def lut_write_to_cache_no_sql_mode(lut_key)
      lut         = {}
      batch_count = 0

      block = lut_proc(lut_key)
      block.call(lut)

      keys = lut.keys

      while
        key_block = keys.slice!(0, lut_options(lut_key)[:batch_size])
        break if key_block.empty?

        lut_block = {}
        key_block.each{|key| lut_block[key] = lut[key]}

        batch_count = self.lut_write_cache_item(lut_key, batch_count, lut_block)
        batch_count += 1
      end

      batch_count
    end

    # Reads a single item of a LookUpTable from Cache
    def lut_read_cache_item(lut_key, lut_item_key)
      prefix = lut_options(lut_key)[:prefix]

      Rails.cache.read("#{prefix}#{lut_key}/#{lut_item_key}")
    end

    # Write a single Item into LookUpTable-Cache
    # TODO: refactor
    def lut_write_cache_item(lut_key, lut_item_count, lut_data)
      prefix  = lut_options(lut_key)[:prefix]
      success = Rails.cache.write("#{prefix}#{lut_key}/#{lut_item_count}", lut_data)

      # Do some magic here and just throw a warning
      # * Divide and conquer on error
      if !success
        warn "WARNING - LookUpTable: Cache.write failed, trying to 'divide and conquer'"

        if lut_data.respond_to?(:keys) && lut_data.respond_to?(:values)
          # Got a hash
          keys        = lut_data.keys
          keys_length = keys.length

          if keys_length < 2
            # Try to slice down values
            entries = lut_data[keys.first].entries

            first_entries  = { keys.first => entries.slice!(0, entries.length/2) }
            second_entries = { keys.first => entries }

            lut_item_count = self.lut_write_cache_item(lut_key, lut_item_count, first_entries)
            lut_item_count = self.lut_write_cache_item(lut_key, lut_item_count + 1, second_entries)

          else
            first_keys  = keys.slice!(0, keys.length/2)
            second_keys = keys
            first_hash  = {}
            second_hash = {}

            first_keys.each  { |k| first_hash[k]  = lut_data[k] }
            second_keys.each { |k| second_hash[k] = lut_data[k] }

            lut_item_count = self.lut_write_cache_item(lut_key, lut_item_count, first_hash)
            lut_item_count = self.lut_write_cache_item(lut_key, lut_item_count + 1, second_hash)
          end
        elsif lut_data.respond_to?(:entries)
          # Got an Array or a Set
          entries = lut_data.entries
          first_entries  = entries.slice!(0, entries.length/2)
          second_entries = entries

          lut_item_count = self.lut_write_cache_item(lut_key, lut_item_count, first_entries)
          lut_item_count = self.lut_write_cache_item(lut_key, lut_item_count + 1, second_entries)
        else
          # Finally we can't help here
          raise "Cache::write failed - Try lower :batch_size"
        end
      end

      return lut_item_count
    end
  end
end


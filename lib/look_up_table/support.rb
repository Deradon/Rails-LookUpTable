# -*- encoding : utf-8 -*-

module LookUpTable
  module ClassMethods

    protected

    def lut_deep_hash_call(method, deep_hash, key, item_key)
      hash = deep_hash ||= {}

      # Passed a Hash as key
      if key.respond_to?(:keys)
        h = {}
        key.each { |k,v| h[k.intern] = self.send(method, k, v) }
        return h
      end

      # Passed a Array or Set as key
      if key.respond_to?(:entries)
        h = {}
        key.entries.each { |e| h[e.intern] = self.send(method, e) }
        return h
      end

      # Passed a Array or Set as item_key
      if item_key.respond_to?(:entries) && key
        h = {}
        item_key.entries.each { |e| h[e] = self.send(method, key, e) }
        return h
      end

      hash = hash[key.intern] if key.respond_to?(:intern)
      hash = hash[item_key]   if item_key

      return hash
    end

  end
end


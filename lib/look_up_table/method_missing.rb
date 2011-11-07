module LookUpTable
  module ClassMethods
    # Delegating <attribute>_lut(args) method calls
    # e.g.: Klass.foo_lut => Klass.lut :foo
    def method_missing(sym, *args, &block)
      method_name = sym.to_s

      if method_name.end_with?("_lut")
        lut_name = method_name[0..-5]
        self.lut(lut_name, args.first)
      else
        super(sym, *args, &block)
      end
    end

    # CHECK: what's bool?
    def respond_to?(sym, bool)
      sym.to_s.end_with?("_lut") || super(sym, bool)
    end
  end
end


class Hash
  def symbolize_keys!
    t=self.dup
    self.clear
    t.each_pair do |k,v|
      case v
      when Hash
        v.symbolize_keys!
      when Array
        v.each do |e|
          if e.kind_of?(Hash)
            e.symbolize_keys!
          end
        end
      end
      self[k.to_sym] = v
      self
    end
    self
  end
end

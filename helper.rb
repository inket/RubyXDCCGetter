class Helper
  attr_accessor :stdout, :stderr

  # bytes -> human readable size
  def self.human_size(n, base = 8)
    return "0" if n.nil?

    units = %w(B KB MB GB)

    unit = units[0]
    size = n

    if n.instance_of?(String)
      unit = n[-2, 2]
      size = n[0..-2].to_f
    end

    if (size >= 1024 && base == 8) || (size >= 1000 && base == 10)
      human_size((base == 8 ? (size / 1024) : (size / 1000)).to_s + units[units.index(unit) + 1], base)
    else
      if size == size.to_i
        return size.to_i.to_s + unit
      else
        index = size.to_s.index(".")

        return size.to_s[0..(index - 1)] + unit if units.index(unit) < 2

        begin
          return size.to_s[0..(index + 2)] + unit
        rescue
          return size.to_s[0..(index + 1)] + unit
        end
      end
    end
  end
end

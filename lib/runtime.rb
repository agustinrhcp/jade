module Runtime
  refine String do
    def __concat__(other)
      self + other
    end
  end
end

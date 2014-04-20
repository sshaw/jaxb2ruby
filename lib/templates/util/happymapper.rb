def accessor_method(node)
  if node.array?
    "has_many"
  elsif node.type.to_s.include?("::")  # Class with namespace?
    "has_one"
  else
    "element"
  end
end

def type_name(node)
  node.type == :boolean ? "Boolean" : node.type
end

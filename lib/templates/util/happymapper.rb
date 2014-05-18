def accessor_method(node)
  if node.array?
    "has_many"
  elsif node.type.to_s.include?("::")  # Class with namespace?
    "has_one"
  else
    "element"
  end
end

# HappyMapper quirk: we need to return false if there's no namespace, otherwise the parent element's
# namespace will be used in XPath searches
def namespace(ns)
  ns.blank? ? "false" : %|"#{ns}"|
end

def type_name(node)
  case node.type
    when :boolean
      "Boolean"
    when "Object"
      "String"
    else
      node.type
  end
end

UNSUPPORTED_TYPES = [:ID, :IDREF, :boolean, "String", "Object"]

def unsupported_type?(type)
  UNSUPPORTED_TYPES.include?(type)
end

def type_name(node)
  name = unsupported_type?(node.type) ? "" : node.type.dup
  # May be an attribute node
  if node.respond_to?(:array?) && node.array?
    name.prepend "["
    name.concat  "]"
  end
  name
end

def accessor_name(node)
  name = ":#{node.accessor}"
  name << "?" if node.type == :boolean
  name
end


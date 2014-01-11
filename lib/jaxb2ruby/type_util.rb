module JAXB2Ruby
  class TypeUtil
    # Only includes types that aren't annotated with @XmlSchemaType
    JAVA_TO_SCHEMA = {
      "java.lang.Boolean" => "boolean",
      "boolean" => "boolean",
      "byte" => "byte",
      # byte[]
      "[B" => "base64Binary",
      "double" => "double",
      "float" => "float",
      "java.lang.Integer" => "int",
      "int" => "int",
      "java.lang.Object" => "anySimpleType",
      "java.lang.String" => "string",
      "java.math.BigDecimal" => "decimal",
      "java.math.BigInteger" => "int",
      "javax.xml.datatype.Duration" => "duration",
      "javax.xml.datatype.XMLGregorianCalendar" => "dateTime",
      #"javax.xml.namespace.QName" => "NOTATION"
      "javax.xml.namespace.QName" => "QName",
      "java.lang.Long" => "long",
      "long" => "long",
      "short" => "short"
    }.freeze

    SCHEMA_TO_RUBY = {
      "ID" => :ID,
      "IDREF" => :IDREF,
      "anyType" => "Object",
      "anySimpleType" => "Object",
      "base64Binary" => "String",
      "boolean" => :boolean,
      "byte" => "Fixnum",
      "date" => "Date",
      "dateTime" => "DateTime",
      "decimal" => "Float",  # BigDecimal
      "double" => "Float",
      "duration" => "String",
      "float"  => "Float",
      "gDay" => "Fixnum",
      "gMonth" => "Fixnum",
      "gMonthDay" => "Fixnum",
      "gYear" => "Fixnum",
      "gYearMonth" => "Fixnum",
      "hexBinary" => "String",
      "int" => "Fixnum",
      "integer" => "Fixnum",
      "long" => "Fixnum",
      "short" => "Fixnum",
      "string" => "String",
      "time" => "Time",
      "unsignedByte" => "Fixnum",
      "unsignedLong" => "Fixnum",
      "unsignedInt" => "Fixnum",
      "unsignedShort" => "Fixnum"
    }.freeze

    def initialize(schema2ruby)
      @schema2ruby = SCHEMA_TO_RUBY.merge(schema2ruby || {})
    end

    def schema_ruby_types
      @schema_types ||= SCHEMA_TO_RUBY.values.uniq
    end

    def java2schema(klass)
      JAVA_TO_SCHEMA[klass]
    end

    def schema2ruby(type)
      @schema2ruby[type]
    end

    def java2ruby(klass)
      schema2ruby(java2schema(klass))
    end
  end
end

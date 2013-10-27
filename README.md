# jaxb2ruby

[![Build Status](https://codeclimate.com/github/sshaw/jaxb2ruby.png)](https://codeclimate.com/github/sshaw/jaxb2ruby)

Generate Ruby objects from an XML schema using [JAXB](https://en.wikipedia.org/wiki/Java_Architecture_for_XML_Binding) and JRuby

<b>DO NOT USE, WORK IN PROGRESS</b>

### Usage

    > jaxb2ruby --help
    usage: jaxb2ruby [options] schema
        -c, --classes=MAP1[,MAP2,...]    Java to Ruby class mappings
                                         MAP can be a string in the form javaclass=rubyclass or a YAML file of java/ruby class pairs
        -h, --help                       Show this message
        -n, --namespace=MAP1[,MAP2,...]  XML namespace to ruby class mappings
                                         MAP can be a string in the form namespace=class or a YAML file of namespace/class pairs
        -o, --output=DIRECTORY           Directory to output the generated ruby classes, defaults to ruby
        -t, --template=NAME              Template used to generate the ruby classes
                                         Can be a path to an ERB template or one of: roxml (default), happymapper, ruby
        -v, --version                    jaxb2ruby version

### Java/Ruby Class Mapping

You can specify your own mapping(s) via the `-c` option.
Otherwise, `jaxb2ruby` will turn Java packages/classes into Ruby modules/class using the following conventions:

* `.` is replaced with `::`
* A package component begining with `_` is replaced with `V`.
* Java inner classes become Ruby inner classes

Some examples:

`com.example.User` becomes `Com::Example::User`

`com.example.API._15.User` becomes `Com::Example::API::V15::User`

`com.example.User$Addresses$Address` results in the creation of 3 classes: `User`, `User::Addresses` 
and `User::Addresses::Address`, all within the `Com::Example` namespace.

Native types are mapped using the following:

boolean :: :boolean
java.lang.Boolean :: :boolean
java.lang.String :: String
java.lang.Integer :: Integer
java.math.BigDecimal :: Integer
java.math.BigInteger :: Integer
javax.xml.datatype.Duration :: String
javax.xml.datatype.XMLGregorianCalendar :: DateTime

Class mappings have precidence over namespace mappings.

### Namespace/Class Mapping

You can specify your own mapping(s) via the `-n` option.

Namespace mappings have a lower precidence than class mappings.

### TODO

* Substitution groups
* Abstract elements
* Uniform handling of XML/Java -> Ruby types
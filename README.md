# jaxb2ruby

[![Build Status](https://travis-ci.org/sshaw/jaxb2ruby.svg)](https://travis-ci.org/sshaw/jaxb2ruby)
[![Build Status](https://codeclimate.com/github/sshaw/jaxb2ruby.png)](https://codeclimate.com/github/sshaw/jaxb2ruby)

Generate pure Ruby classes from an XML schema using [JAXB](https://en.wikipedia.org/wiki/Java_Architecture_for_XML_Binding) and JRuby

### Usage

    > jaxb2ruby --help
    usage: jaxb2ruby [options] schema
        -c, --classes=MAP1[,MAP2,...]    XML Schema type to Ruby class mappings
                                         MAP can be a string in the form type=class or a YAML file of type/class pairs
        -h, --help                       Show this message
        -I, --include=DIRECTORY          Add DIRECTORY to the load path, usefull for using custom template helpers
        -n, --namespace=MAP1[,MAP2,...]  XML namespace to ruby class mappings
                                         MAP can be a string in the form namespace=class or a YAML file of namespace/class pairs
        -o, --output=DIRECTORY           Directory to output the generated ruby classes, defaults to ruby
        -t, --template=NAME              Template used to generate the ruby classes
                                         Can be a path to an ERB template or one of: roxml (default), happymapper, ruby
        -v, --version                    jaxb2ruby version
		-w, --wsdl                       Treat the schema as a WSDL
                                         Automatically set if the schema has a `.wsdl' extension

### Instalation

    gem install jaxb2ruby

`jaxb2ruby` must be installed and ran under JRuby. The generated classes *will not* depend on JRuby.

### Ruby Class Mappings

#### XML Schema Built-in Types

XML Schema types will be mapped to the following Ruby types:

TODO

You can specify your own XML Schema to Ruby type mapping(s) via the `-c` option.

#### XML Schema Complex Types

Complex schema types will `camelized` and turned into Ruby classes. If a type has a namespace
the namespace will be converted into a module and the resulting class will be placed inside.

Namespaces are turned into modules using a slightly modified version of the rules outlined in the [The Java Architecture for XML Binding (JAXB) 2.0](http://download.oracle.com/otndocs/jcp/jaxb-2.0-fr-eval-oth-JSpec) Section D.5.1 _Mapping from a Namespace URI_. The differences being:

* The list of module/package strings are joined on `"::"`
* A module/package string beginning with `"_"` is replaced with `"V"`
* Nested, anonymous XML schema types become Ruby inner classes

Some examples:

`{http://example.com}User` becomes `Com::Example::User`

`{http://example.com/api/15}User` becomes `Com::Example::Api::V15::User`

An XML schema type `{http://example.com}User` that contains the nested complex type
`Addresses`, which itself contains the type `Address` will result in the creation
of 3 classes: `User`, `User::Addresses` and `User::Addresses::Address`, all within
the `Com::Example` namespace.

You can specify your own namespace to class mapping(s) via the `-n` option.
Namespace mappings have a lower precedence than type mappings.

### Code Templates

`jaxb2ruby` uses ERB templates to create Ruby classes. You can use one of the included templates
or [create your own](#rolling-out-your-own-templates). Use the `-t` option to specify the desired template, they are:

* `roxml` the default ([ROXML](https://github.com/Empact/roxml))
* `happymapper` ([HappyMapper](https://github.com/jnunemaker/happymapper))
* `ruby` - plain 'ol Ruby classes

Note that "plain 'ol Ruby classes" does not perform XML serialization.

#### Rolling out your own templates

Use the `-t` option to specify the path to your template. This *must* be a path else it will be interpreted as a [jaxb2ruby template](#Code-Templates).
Two variables will be provided to your template:

1. `@class`, an instance of `RubyClass` (http://ruby-doc.org/gems/docs/j/jaxb2ruby-0.0.1/JAXB2Ruby/RubyClass.html)
2. `VERSION` the version of `jaxb2ruby`

See `lib/templates` for some examples.

You can use helper functions in your templates by providing the helper file's directory to the `-I` option.

### TODO

* Qualified namespaces i.e., elementFormDefault="qualified"

### Author

Skye Shaw [sshaw AT gmail.com]

### License

Released under the MIT License: www.opensource.org/licenses/MIT

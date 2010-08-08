#!/usr/bin/env jruby

include Java

java_import 'org.antlr.runtime.ANTLRFileStream'
java_import 'org.antlr.runtime.TokenRewriteStream'
java_import 'org.antlr.runtime.Token'
java_import 'org.antlr.runtime.tree.TreeAdaptor'
java_import 'org.antlr.runtime.tree.CommonTreeAdaptor'
java_import 'org.antlr.runtime.tree.BaseTree'
java_import 'org.antlr.runtime.tree.CommonTree'
java_import 'org.lslcc.antlr.LslLexer'
java_import 'org.lslcc.antlr.LslParser'

# like attr_accessor, except that it sets @parent in the value assigned
def node_accessor( *symbols )
  # set the @parent variable in a node, or all the nodes in an array
  def set_parent(n, p)
    if n.respond_to? :parent
      n.instance_variable_set(:@parent, p)
    elsif n.kind_of? Enumerable and not n.kind_of? String
      # String is Enumerable, and returns String when Enumerated, causing
      # infinite recursion D:
      n.each {|nn| set_parent(nn, p)}
    end
  end
  attr_accessor(*symbols)
  symbols.each do |sym|
    define_method("#{sym}=".to_sym) do |value|
      isym = "@#{sym}".to_sym
      # if there is already a value, set that value's @parent to nil
      if instance_variable_defined? isym
        old = instance_variable_get(isym)
        set_parent(old, nil) if old
      end
      # set our new value
      instance_variable_set(isym, value)
      # set the new value's @parent to self
      set_parent(value, self) if value
    end
  end
end

# the tree class used by Antlr
class LslTree < CommonTree
  # map of integer token types to Node subclasses
  @@clsmap = nil
  # map of integer tokens to field names(TYPE -> type)
  @@namemap = nil
  # return an empty array instead of null when there are now children
  def children
    a = super
    return [] unless a
    return a
  end
  # properly duplicate nodes
  def dupNode
    self.class.new(self)
  end
  # convert this subtree into the proper class from the Lsl module
  def convert
    make_maps unless @@clsmap
    cls = @@clsmap[token.type]
    if cls
      # this node converts to an Lsl type
      node = cls.new
      others = []

      children.each do |child|
        # get the field name associated with the child's token type
        name = @@namemap[child.type]
        # names that end in 's' are taken to be arrays
        if name and name.end_with? 's'
          c = child.children.map {|gc| gc.convert}
        else
          c = child.convert
        end
        if name
          # determine setter method
          name += '='
          if node.respond_to? name
            # send setter method
            node.__send__(name.to_sym, c)
          elsif node.respond_to? :value=
            # fallback to setting single value
            node.value = c
          else
            # store in array to set values field later
            others << c
          end
        elsif node.respond_to? :value=
          # fallback to setting single value(because we don't know the name)
          node.value = c
        else
          # store in array to set values field later
          others << c
        end
      end
      if node.respond_to? :values=
        # set values field(possible empty)
        node.values = others
      elsif others.length != 0
        # we're about to discard part of the tree!
        raise "We have an array of values(#{others.inspect}), but #{node.class.to_s} does not accept a values array."
      end
      return node
    end
    return case children.length
      when 0 then self.text
      when 1 then children.first.convert
      else raise "collection of child nodes(#{o.inspect}) inside unknown node #{self.text}"
    end
  end

  private
  # build our map of IDs
  def make_maps
    java_class.synchronized do
      unless @@clsmap
        # IDs to classes
        @@clsmap = {}
        # IDs to field names
        @@namemap = {}
        # get classes
        lsl_constants = Lsl.constants
        # get all constants from LslParser(might be token names)
        LslParser.constants.each do |constant|
          # convert CONSTANT_NAME to field_name and ClassName
          fieldname = constant.downcase
          clsname = fieldname.split('_').each{|part| part.capitalize!}.join
          value = LslParser.const_get(constant)
          next unless value.kind_of? Fixnum
          @@namemap[value] = fieldname
          # check for existance
          if lsl_constants.include? clsname then
            cls = Lsl.const_get(clsname)
            # check for types and record
            @@clsmap[value] = cls if cls.kind_of? Class and cls != Lsl::Node
          end
        end
      end
    end
  end
end

module Lsl
  # all nodes should have a parent field
  class Node
    attr_reader :parent
  end

  class Type < Node
    node_accessor :value
    def default_value
      case value
      when 'VOID' then nil
      when 'integer' then '0'
      when 'float' then '0.0'
      when 'string' then '""'
      when 'key' then '""'
      when 'vector' then '<0.0, 0.0, 0.0>'
      when 'rotation' then '<0.0, 0.0, 0.0, 0.0>'
      when 'list' then '[]'
      else raise "Unknown type #{value}"
      end
    end
    def to_s
      return '' if is_void?
      return value.to_s
    end
    def is_void?
      return value == 'VOID'
    end
  end

  class Script < Node
    node_accessor :globals, :states
    def to_s
      "#{globals.join("\n")}\n#{states.join("\n")}"
    end
  end

  class Variable < Node
    node_accessor :type, :name, :value
    def to_s
      v = value
      v = type.default_value unless v
      return "#{type} #{name} = #{v};"
    end
  end

  class Function < Node
    node_accessor :type, :name, :params, :body
    def to_s
      ret = ''
      ret = "#{type} " unless type.is_void?
      ret += "#{name}(#{params.join(', ')})\n#{body}"
    end
  end

  class Param < Node
    node_accessor :type, :name
    def to_s
      "#{type} #{name}"
    end
  end

  class Value < Node
    node_accessor :values
    def to_s
      values.join(' ')
    end
  end

  class State < Node
    node_accessor :name, :events
    def to_s
      "#{name} {\n#{events.join("\n")}\n}"
    end
  end

  class StateChange < Node
    node_accessor :value
    def to_s
      "state #{value};"
    end
  end

  class Jump < Node
    node_accessor :value
    def to_s
      "jump #{value};"
    end
  end

  class Label < Node
    node_accessor :value
    def to_s
      "@#{value};"
    end
  end

  class Return < Node
    node_accessor :value
    def to_s
      v = value
      return 'return;' unless v
      return "return #{v};"
    end
  end

  class Call < Node
    node_accessor :name, :params
    def to_s
      "#{name}(#{params.join(', ')})"
    end
  end

  class Cast < Node
    node_accessor :type, :value
    def to_s
      "(#{type})#{value}"
    end
  end

  class Body < Node
    node_accessor :values
    def initialize
      @values = []
    end
    def to_s
      return values.first.to_s if values.length == 1 and (parent.kind_of? Body or values.first.kind_of? Body)
      "{\n#{values.join("\n")}\n}"
    end
  end

  class If < Node
    node_accessor :condition, :body, :else
    def to_s
      s = "if (#{condition})\n#{self.body}\nelse\n"
      #raise "#{self.else.class} #{self.else.to_s}"
      if self.else then
        s += self.else.to_s
      else
        s += ';'
      end
      return s
    end
  end

  class While < Node
    node_accessor :condition, :body
    def to_s
      "while (#{condition})\n#{body}"
    end
  end

  class Do < While
    def to_s
      "do\n#{body}\nwhile (#{condition})"
    end
  end

  class For < Node
    node_accessor :precommands, :condition, :loopcommands, :body
    def to_s
      "for (#{precommands.join(', ')}; #{condition}; #{loopcommands.join(', ')})\n#{body}"
    end
  end

  class Expression < Value
    def to_s
      s = super.to_s
      s += ';' if parent.kind_of? Body
      s = "(#{s})" if parent.kind_of? Value
      s
    end
  end

  class Condition < Value
  end

  class List < Node
    node_accessor :values
    def to_s
      "[#{values.join(', ')}]"
    end
  end
end

class LslTreeAdaptor < CommonTreeAdaptor
  def create( token )
    if token
      return LslTree.new(token)
    end
    # JRuby doesn't work for LslTree.new(nil)
    # these nodes all get deleted before the tree leaves Antlr anyway
    return CommonTree.new(token)
  end
end

class Lslcc
  java_signature 'void main(String[])'
  def self.main(args)
    args.each do |file|
      lex = LslLexer.new(ANTLRFileStream.new(file, 'utf-8'))
      tokens = TokenRewriteStream.new(lex)
      grammar = LslParser.new(tokens)
      grammar.set_tree_adaptor(LslTreeAdaptor.new)
      ret = grammar.lscriptProgram
      tree = ret.tree.convert
      puts tree
    end
  end
end

Lslcc.main(ARGV)

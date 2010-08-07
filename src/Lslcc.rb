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

module Lsl
  class LslTree < CommonTree
    def children
      a = super
      return [] unless a
      return a
    end
    def dupNode
      self.class.new(self)
    end
  end

  class Type < LslTree
    def default_value
      type = child(0).token.type
      return nil if type == LslParser::VOID
      return '0' if type == LslParser::INTEGER_TYPE
      return '0.0' if type == LslParser::FLOAT_TYPE
      return '""' if type == LslParser::STRING_TYPE
      return '""' if type == LslParser::LLKEY_TYPE
      return '<0.0, 0.0, 0.0>' if type == LslParser::VECTOR_TYPE
      return '<0.0, 0.0, 0.0, 0.0>' if type == LslParser::QUATERNION_TYPE
      return '[]' if type == LslParser::LIST_TYPE
      raise "Unknown type #{child(0).token.text}"
    end
    def to_s
      token = child(0).token
      return '' if token.type == LslParser::VOID
      return token.text
    end
    def is_void?
      return child(0).token.type == LslParser::VOID
    end
  end

  class Script < LslTree
    def globals
      first_child_with_type(LslParser::GLOBALS).children
    end
    def states
      first_child_with_type(LslParser::STATES).children
    end
    def to_s
      "#{globals.join("\n")}\n#{states.join("\n")}"
    end
  end

  class Variable < LslTree
    def type
      first_child_with_type(LslParser::TYPE)
    end
    def name
      first_child_with_type(LslParser::NAME).child(0)
    end
    def value
      node = first_child_with_type(LslParser::VALUE)
      return type.default_value unless node
      node
    end
    def to_s
      return "#{type} #{name} = #{value};"
    end
  end

  class Function < LslTree
    def type
      first_child_with_type(LslParser::TYPE)
    end
    def name
      first_child_with_type(LslParser::NAME).child(0)
    end
    def params
      first_child_with_type(LslParser::PARAMS).children
    end
    def body
      first_child_with_type(LslParser::BODY)
    end
    def to_s
      ret = ''
      ret = "#{type} " unless type.is_void?
      ret += "#{name}(#{params.join(', ')})\n#{body}"
    end
  end

  class Param < LslTree
    def type
      first_child_with_type(LslParser::TYPE)
    end
    def name
      first_child_with_type(LslParser::NAME).child(0)
    end
    def to_s
      "#{type} #{name}"
    end
  end

  class Value < LslTree
    def to_s
      children.join(' ')
    end
  end

  class State < LslTree
    def name
      first_child_with_type(LslParser::NAME).child(0)
    end
    def events
      first_child_with_type(LslParser::BODY).children
    end
    def to_s
      "#{name} {\n#{events.join("\n")}\n}"
    end
  end

  class StateChange < LslTree
    def target
      child(0)
    end
    def to_s
      "state #{name};"
    end
  end

  class Jump < LslTree
    def target
      child(0)
    end
    def to_s
      "jump #{name};"
    end
  end

  class Label < LslTree
    def name
      child(0)
    end
    def to_s
      "@#{name};"
    end
  end

  class Return < LslTree
    def value
      child(0)
    end
    def to_s
      v = child(0)
      return 'return;' unless v
      return "return #{v};"
    end
  end

  class Call < LslTree
    def target
      first_child_with_type(LslParser::NAME).child(0)
    end
    def params
      first_child_with_type(LslParser::PARAMS).children
    end
    def to_s
      "#{target}(#{params.join(', ')})"
    end
  end
  class Cast < LslTree
    def type
      first_child_with_type(LslParser::TYPE)
    end
    def value
      first_child_with_type(LslParser::VALUE)
    end
    def to_s
      "(#{type})#{value}"
    end
  end
  class Body < LslTree
    def to_s
      return child(0).to_s if child_count == 1 and child(0).type == LslParser::BODY
      "{\n#{children.join("\n")}\n}"
    end
  end
  class If < LslTree
    def condition
      first_child_with_type(LslParser::CONDITION)
    end
    def then
      first_child_with_type(LslParser::BODY).child(0)
    end
    def else
      first_child_with_type(LslParser::ELSE).child(0)
    end
    def to_s
      s = "if (#{condition})\n#{self.then}\nelse\n"
      if self.else then
        s += self.else.to_s
      else
        s += ';'
      end
      return s
    end
  end
  class While < LslTree
    def condition
      first_child_with_type(LslParser::CONDITION)
    end
    def body
      first_child_with_type(LslParser::BODY).child(0)
    end
    def to_s
      "while (#{condition})\n#{body}"
    end
  end
  class Do < While
    def to_s
      "do\n#{body}\nwhile (#{condition})"
    end
  end
  class For < LslTree
    def precommands
      first_child_with_type(LslParser::PRECOMMAND).children
    end
    def condition
      first_child_with_type(LslParser::CONDITION)
    end
    def loopcommands
      first_child_with_type(LslParser::LOOPCOMMAND).children
    end
    def body
      first_child_with_type(LslParser::BODY).child(0)
    end
    def to_s
      "for (#{precommands.join(', ')}; #{condition}; #{loopcommands.join(', ')})\n#{body}"
    end
  end
  class Expression < Value
    def to_s
      s = super.to_s
      s += ';' if parent.type == LslParser::BODY
      s = "(#{s})" if parent.kind_of? Value
      s
    end
  end
  class Condition < Value
  end
  class List < LslTree
    def values
      children
    end
    def to_s
      "[#{values.join(', ')}]"
    end
  end
end

class LslTreeAdaptor < CommonTreeAdaptor
  def initialize
    # build a map from token type IDs to classes in Lsl module
    @map = {}
    lsl_constants = Lsl.constants
    LslParser.constants.each do |constant|
      # convert CONSTANT_NAME to ClassName
      clsname = constant.downcase.split('_').each{|part| part.capitalize!}.join
      # check for existance
      if lsl_constants.include? clsname then
        value = LslParser.const_get(constant)
        cls = Lsl.const_get(clsname)
        # check for types and record
        @map[value] = cls if value.kind_of? Fixnum and cls.kind_of? Class
      end
    end
  end
  def create( token )
    if token
      cls = @map[token.type]
      return cls.new(token) if cls

      return Lsl::LslTree.new(token)
    end
    return CommonTree.new(token)
  end
end

class Lslcc
  def self.print_tree(tree, indent)
    if tree then
      children = tree.children
      if children then
        tree.children.each do |child|
          puts "#{' ' * indent}#{child.text}"
          print_tree(child, indent + 1)
        end
      end
    end
  end
  java_signature 'void main(String[])'
  def self.main(args)
    args.each do |file|
      lex = LslLexer.new(ANTLRFileStream.new(file, 'utf-8'))
      tokens = TokenRewriteStream.new(lex)
      grammar = LslParser.new(tokens)
      grammar.set_tree_adaptor(LslTreeAdaptor.new)
      ret = grammar.lscriptProgram
      tree = ret.tree
      puts tree
    end
  end
end

Lslcc.main(ARGV)

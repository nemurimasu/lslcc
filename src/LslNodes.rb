#!/usr/bin/env jruby

# like attr_accessor, except that it sets parent in the value assigned
def node_accessor( *symbols )
  attr_accessor(*symbols)
  symbols.each do |sym|
    define_method("#{sym}=".to_sym) do |value|
      isym = "@#{sym}".to_sym
      # if there is already a value, set that value's parent to nil
      if respond_to? sym
        old = instance_variable_get(isym)
        old.parent = old if old and old.respond_to? :parent=
      end
      # set our new value
      instance_variable_set(isym, value)
      # set the new value's parent to self
      value.parent = self if value and value.respond_to? :parent=
    end
  end
end

module Lsl
  # all nodes should have a parent field
  class Node
    attr_accessor :parent

    def initialize( vars = {} )
      if vars.kind_of? Hash
        vars.keys.each do |k|
          sym = "#{k}=".to_sym
          __send__(sym, vars[k]) if respond_to? sym
        end
      elsif vars.kind_of? Array and respond_to? :values=
        self.values = vars
      else
        self.value = vars
      end
    end

    # override this in nodes that can contain functions
    def all_functions
      return []
    end
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
    def all_functions
      return ((globals + states).map {|g| g.all_functions}).flatten!(1)
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

    def all_functions
      return [self]
    end
  end

  class Param < Node
    node_accessor :type, :name
    def to_s
      "#{type} #{name}"
    end
  end

  class Value < Node
    node_accessor :left, :right, :center
    Precedences = [['=', '+=', '-=', '*=', '/=', '%='], ['||'], ['&&'], ['|'], ['^'], ['&'], ['==', '!='], ['<', '<=', '>', '>='], ['<<', '>>'], ['+', '-'], ['*', '/', '%'], ['.']] # http://lslwiki.net/lslwiki/wakka.php?wakka=LSL101Chapter4/show&time=2008-09-25+16%3A15%3A07
    # expressions coming in from Antlr are not in proper trees
    def values=( values )
      if values.empty?
        raise "values is empty(syntax gap >.<)"
        self.center = ''
        return
      end
      if values.length == 1
        self.center = values.first
        return
      end
      Precedences.each do |level|
        values.length.times do |i|
          if level.include? values[i] then
            if i > 0
              if i == 1 and values.first.kind_of? Value
                self.left = values.first
              else
                self.left = Value.new(values[0...i])
              end
            end
            if i + 1 < values.length
              if i + 2 == values.length and values.last.kind_of? Value
                self.right = values.last
              else
                self.right = Value.new(values[0...i])
              end
            end
            self.center = values[i]
            return
          end
        end
      end
      p values.map { |v| case v.class.to_s; when 'String' then v; else v.class; end }
      raise 'partial value(syntax gap >.<)'
    end
    def to_s
      r = "#{center}"
      r = "#{left}#{r}" if left
      r = "#{r}#{right}" if right
      r = "(#{r})" if left or right
      return r
    end
  end

  class State < Node
    node_accessor :name, :events
    def to_s
      "#{name} {\n#{events.join("\n")}\n}"
    end
    def all_functions
      return events
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
    def initialize( vars = [] )
      super
    end
    def to_s
      return values.first.to_s if values.length == 1 and (parent.kind_of? Body or values.first.kind_of? Body)
      "{\n#{values.join("\n")}\n}"
    end
    def insert( index, value )
      value.parent = self if value and value.respond_to? :parent=
      values.insert(index, value)
    end
  end

  class If < Node
    node_accessor :condition, :body, :else
    def to_s
      s = "if (#{condition})\n#{self.body}\nelse\n"
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
      s = super
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

  class Vector < Node
    node_accessor :values
    def to_s
      "<#{values.join(', ')}>"
    end
    def x
      values[0]
    end
    def x=( value )
      values[0] = value
    end
    def y
      values[1]
    end
    def y=( value )
      values[1] = value
    end
    def z
      values[2]
    end
    def z=( value )
      values[2] = value
    end
  end

  class Quaternion < Vector
    def s
      values[3]
    end
    def s=( value )
      values[3] = value
    end
  end

  class PreMod < Node
    node_accessor :operator, :value
    def to_s
      "#{operator}#{value}"
    end
  end

  class PostMod < Node
    node_accessor :operator, :value
    def to_s
      "#{value}#{operator}"
    end
  end
end

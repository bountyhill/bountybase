# Author::    radiospiel  (mailto:eno@radiospiel.org)
# Copyright:: Copyright (c) 2011, 2012 radiospiel
# License::   Distributes under the terms  of the Modified BSD License, see LICENSE.BSD for details.
module Expectations
  def expect!(*expectations, &block)
    if block_given?
      Expectations.verify! true, block
    end
    
    expectations.each do |expectation|
      case expectation
      when Hash
        expectation.each do |value, e|
          Expectations.verify! value, e
        end
      else
        Expectations.verify! expectation, :truish
      end
    end
  end

  def self.met?(value, expectation)
    case expectation
    when :truish  then !!value
    when Array    then expectation.any? { |e| met?(value, e) }
    when Proc     then expectation.arity == 0 ? expectation.call : expectation.call(value)
    when Regexp   then expectation =~ value.to_s
    else          expectation === value
    end
  end

  def self.verify!(value, expectation)
    if expectation.is_a?(Hash)
      verify! value, Hash
      
      expectation.each do |key, expectations_for_key|
        verify! value[key], expectations_for_key
      end
      return
    end
    
    return if met?(value, expectation)

    backtrace = caller[3..-1]
    
    e = ArgumentError.new "#{value.inspect} does not meet expectation #{expectation.inspect}"
    e.singleton_class.send(:define_method, :backtrace) do
      backtrace
    end
    raise e
  end
end

Object.send :include, Expectations

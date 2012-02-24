# Started with https://github.com/postmodern/cparser code
# which is based on http://www.lysator.liu.se/c/ANSI-C-grammar-y.html
# and worked from there
# 
# The second link really helped when it came to functions

class Kalc::Grammar < Parslet::Parser

  rule(:new_line) { match('[\n\r]').repeat(1) }

  rule(:space) { match('[ \t\v\n\f]') }
  rule(:spaces) { space.repeat(1) }
  rule(:space?) { space.maybe }
  rule(:spaces?) { space.repeat }

  rule(:digit) { match('[0-9]') }
  rule(:digits) { digit.repeat(1) }
  rule(:digits?) { digit.repeat }

  rule(:alpha) { match('[a-zA-Z]') }

  def self.symbols(symbols) 
    symbols.each do |name, symbol|
      rule(name) { str(symbol) >> spaces? }
    end
  end

  symbols :left_paren => '(',
          :right_paren => ')',
          :comma => ',',
          :colon => ':',
          :semicolon => ';'

  def self.operators(operators={})
    trailing_chars = Hash.new { |hash,symbol| hash[symbol] = [] }

    operators.each_value do |symbol|
      operators.each_value do |op|
        if op[0,symbol.length] == symbol
          char = op[symbol.length,1]

          unless (char.nil? || char.empty?)
            trailing_chars[symbol] << char
          end
        end
      end
    end

    operators.each do |name,symbol|
      trailing = trailing_chars[symbol]

      if trailing.empty?
        rule(name) { str(symbol).as(:operator) >> spaces? }
      else
        pattern = "[#{Regexp.escape(trailing.join)}]"

        rule(name) {
          (str(symbol) >> match(pattern).absnt?).as(:operator) >> spaces?
        }
      end
    end
  end

  operators :logical_and => '&&',
            :logical_or => '||',
            :less_equal => '<=',
            :greater_equal => '>=',
            :equal => '==',
            :not_equal => '!=',

            :assign => '=',
            :question_mark => '?',

            :subtract => '-',
            :add => '+',
            :multiply => '*',
            :divide => '/',
            :modulus => '%',

            :less => '<',
            :greater => '>'

  rule(:and_keyword) { str('AND') }
  rule(:or_keyword) { str('OR') }
  rule(:if_keyword) { str('IF') }

  rule(:number) {
    (match('[+-]').maybe >> digits >> (str('.') >> digits).maybe).as(:number) >> spaces?
  }

  rule(:identifier) {
    (alpha >> (alpha | digit).repeat) >> spaces?
  }

  rule(:argument) {
    identifier.as(:argument)
  }

  # Should look like 'Name'
  rule(:variable) {
    (str("'") >> identifier >> str("'")) >> spaces?
  }

  # Does not self-evaluate
  # Use to call function: FUNCTION_NAME(variable_list, ..)
  rule(:variable_list) {
    conditional_expression >> (comma >> conditional_expression).repeat
  }

  rule(:paren_variable_list) {
    (left_paren >> variable_list.repeat >> right_paren).as(:paren_list)
  }

  # Does not self-evaluate
  # Used to create function: DEF FUNCTION_NAME(argument_list, ..)
  rule(:argument_list) {
    argument >> (comma >> argument).repeat
  }

  rule(:paren_argument_list) {
    (left_paren >> argument_list.repeat >> right_paren).as(:paren_list)
  }

  # Atoms can self-evaluate
  # This where the grammar starts
  rule(:atom) {
    variable.as(:variable) | number | paren_expression
  }

  # (1 + 2)
  rule(:paren_expression) {
    left_paren >> conditional_expression >> right_paren
  }

  # IF(1, 2, 3)
  # AND(1, 2, ...)
  rule(:function_call_expression) {
    (identifier.as(:name) >> paren_variable_list.as(:variable_list)).as(:function_call) |
    atom
  }

  # 1 * 2
  rule(:multiplicative_expression) {
    function_call_expression.as(:left) >> 
      (multiply | divide | modulus) >> 
      multiplicative_expression.as(:right) |
    function_call_expression
  }

  # 1 + 2
  rule(:additive_expression) {
    multiplicative_expression.as(:left) >> 
      (add | subtract) >> 
      additive_expression.as(:right) |
    multiplicative_expression
  }

  # 1 < 2
  # 1 > 2
  # 1 <= 2
  # 1 >= 2
  rule(:relational_expression) {
    additive_expression.as(:left) >> 
      (less | greater | less_equal | greater_equal) >>
      relational_expression.as(:right) |
    additive_expression
  }

  # 1 == 2
  rule(:equality_expression) {
    relational_expression.as(:left) >>
      (equal | not_equal) >>
      equality_expression.as(:right) |
    relational_expression
  }

  # 1 && 2
  rule(:logical_and_expression) {
    equality_expression.as(:left) >>
      logical_and >>
      logical_and_expression.as(:right) |
    equality_expression
  }

  # 1 || 2
  rule(:logical_or_expression) {
    logical_and_expression.as(:left) >>
      logical_or >>
      logical_or_expression.as(:right) |
    logical_and_expression
  }

  # 1 > 2 ? 3 : 4
  rule(:conditional_expression) {
    logical_or_expression.as(:condition) >> 
      question_mark >> 
      conditional_expression.as(:true) >> 
      colon >> 
      conditional_expression.as(:false) | 
    logical_or_expression
  }

  # 'a' = 1
  # We don't allow for nested assignments:
  # IF('a' = 1, 1, 2)
  rule(:assignment_expression) {
    (variable.as(:identifier) >> 
      assign >> 
      conditional_expression.as(:value)).as(:assign) |
    conditional_expression
  }

  # Start here
  rule(:expression) {
    assignment_expression
  }

  root :expression
end


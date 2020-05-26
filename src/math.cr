require "big"
require "option_parser"

record Settings,
  rows = 3,
  columns = 10,
  seed = 1,
  operation : Operation::ANY.class = Operation::RandomProblem,
  show_results = true

struct Settings
  def random_rationals
    amount = rows * columns
    rand = Random.new(seed)
    found = [] of String
    until found.size >= amount
      result = operation.new(rand)

      if result.simple?
        formatted = result.to_asciimath(show_results)
        found << formatted
        found.uniq!
      end
    end

    found
  end

  def generate_questions
    copy_with(show_results: false).generate("Questions")
  end

  def generate_answers
    copy_with(show_results: true).generate("Answers")
  end

  def generate(name)
    title = "##{seed} : #{name}"
    Process.run("asciidoc", ["--backend", "html5", "-a", "asciimath", "-o", "#{name}.html", "-"]) do |process|
      io = process.input
      io.puts title
      io.puts "-" * title.size
      io.puts
      io.puts ":Revision: #{seed}"
      io.puts
      io.puts
      io.puts "|===================================="
      random_rationals.each_slice(rows) do |rats|
        rats.each do |rat|
          io.print "|"
          io.print rat
        end
        io.puts
      end
      io.puts "|===================================="
    end
  end
end

settings = Settings.new

OptionParser.parse ARGV do |o|
  o.banner = "Usage: math [flags]"
  o.on("-h", "--help", "Help") { puts o; exit 0 }
  o.on("-r=NUMBER", "--rows=NUMBER", "Number of rows") { |value| settings = settings.copy_with rows: value.to_i }
  o.on("-c=NUMBER", "--columns=NUMBER", "Number of columns") { |value| settings = settings.copy_with columns: value.to_i }
  o.on("-s=NUMBER", "--seed=NUMBER", "RNG Seed") { |value| settings = settings.copy_with seed: value.to_i }
  o.on("-o=OP", "--operation=OP", "mul, div, add, sub, rand") { |value|
    operation =
      case value
      when "mul"
        Operation::FractionMultiplication
      when "div"
        Operation::FractionDivision
      when "add"
        Operation::FractionAddition
      when "sub"
        Operation::FractionSubstraction
      when "rand"
        Operation::RandomProblem
      else
        STDERR.puts "Unknown operation: #{value}"
        puts o
        exit 1
      end
    settings = settings.copy_with operation: operation
  }
  o.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts o
    exit 1
  end
end

struct BigRational
  def easy?
    (denominator < 2) || (numerator < 2)
  end

  def hard?
    (denominator > 50) || (numerator > 50)
  end

  def acceptable?
    !easy? && !hard? && denominator > 1 && numerator > 1 && numerator < denominator
  end
end

module Operation
  alias ANY = RandomProblem | FractionSubstraction | FractionAddition | FractionDivision | FractionMultiplication

  RANDOM_OPERATIONS = [
    Operation::FractionMultiplication,
    Operation::FractionAddition,
    Operation::FractionSubstraction,
  ]

  abstract class FractionOperation
    property left : BigRational
    property right : BigRational
    property seed : Random

    abstract def result : BigRational
    abstract def to_asciimath(show_result : Bool) : String

    def initialize(@left, @right)
      @seed = Random.new
    end

    def initialize(seed)
      @seed = seed
      @left = random_rational(seed)
      @right = random_rational(seed)
    end

    def random_rational(seed)
      result = BigRational.new(1, 1)

      until result.acceptable?
        denominator = seed.rand(2..999)
        numerator = seed.rand(2..denominator)
        result = BigRational.new(numerator, denominator)
      end

      result
    end

    def simple?
      r = result
      (2..100).includes?(r.numerator) && (2..100).includes?(r.denominator) && r.numerator <= r.denominator
    end
  end

  class RandomProblem < FractionOperation
    property operation : FractionOperation?

    def selected_operation
      @operation ||= RANDOM_OPERATIONS.sample(seed).new(@left, @right)
    end

    def result : BigRational
      selected_operation.result
    end

    def to_asciimath(show_result : Bool) : String
      selected_operation.to_asciimath(show_result)
    end
  end

  class FractionMultiplication < FractionOperation
    def result : BigRational
      @left * @right
    end

    def to_asciimath(show_result : Bool) : String
      if show_result
        "asciimath:[#{@left} * #{@right} = #{result}]"
      else
        "asciimath:[#{@left} * #{@right} =]"
      end
    end
  end

  class FractionDivision < FractionOperation
    def result : BigRational
      @left / @right
    end

    def to_asciimath(show_result : Bool) : String
      if show_result
        "asciimath:[#{@left} : #{@right} = #{result}]"
      else
        "asciimath:[#{@left} : #{@right} =]"
      end
    end
  end

  class FractionSubstraction < FractionOperation
    def result : BigRational
      @left - @right
    end

    def to_asciimath(show_result : Bool) : String
      if show_result
        "asciimath:[#{@left} - #{@right} = #{result}]"
      else
        "asciimath:[#{@left} - #{@right} =]"
      end
    end
  end

  class FractionAddition < FractionOperation
    def result : BigRational
      @left + @right
    end

    def to_asciimath(show_result : Bool) : String
      if show_result
        "asciimath:[#{@left} + #{@right} = #{result}]"
      else
        "asciimath:[#{@left} + #{@right} =]"
      end
    end
  end
end

settings.generate_questions
settings.generate_answers

module OrgConverge
  class Command
    attr_reader :dotorg

    def initialize(options)
      @options = options
      @dotorg  = options['<org_file>']
    end

    def execute!
      case
      when @options['--showfiles']
        showfiles
      end      
    end

    def showfiles
      ob = Orgmode::Parser.new(File.read(dotorg)).babelize

      ob.tangle.each do |file, lines|
        puts "---------- #{file} --------------".green
        lines.each do |line|
          puts line
        end
      end

      ob.scripts.each_with_index do |script, index|
        puts "---------- script: #{index} --------------".green
        puts script
      end
    end
  end
end

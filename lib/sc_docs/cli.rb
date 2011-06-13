require 'thor'

require 'sc_docs/generator'

module ScDocs
  class CLI < Thor

    class_option :update, :aliases => ['-u'], :type => :boolean, :default => false,
      :banner => "If input is a git repo, pull and rebase"
    class_option :app_mode, :aliases => ['-a'], :type => :boolean, :default => false,
      :banner => "Generates the Docs application. Otherwise, generates template-based docs"
    class_option :template, :aliases => ['-t'], :type => :string, :default => "docs.sproutcore.com",
      :banner => "Templates to use when generating docs; not valid when generating in app mode"
    class_option :verbose, :aliases => ['-v'], :type => :boolean, :default => false
    class_option :config_file, :aliases => ['-c'], :type => :string,
      :banner => "jsdoc configuration file"

    desc "generate [DIRECTORIES...]", "Generate docs"
    method_option :output_dir, :aliases => ['-o'], :type => :string, :required => true,
      :banner => "Directory to output docs to"
    method_option :project, :aliases => ['-p'], :type => :string,
      :banner => "SproutCore Project Name"
    def generate(*directories)
      raise "At least one directory is required" if directories.empty?
      puts "Generating Documentation...\n\n"
      update_repo(directories)
      generator(directories).generate
    end

    desc "preview [DIRECTORIES...]", "Preview docs output"
    method_option :output_dir, :aliases => ['-o'], :type => :string, :required => false,
      :banner => "Directory to output docs to (defaults to a tempfile)"
    def preview(*directories)
      raise "At least one directory is required" if directories.empty?
      puts "Building Documentation Preview...\n\n"
      update_repo(directories)
      with_temp_output{ generator(directories).preview }
    end

    private

      def output_dir
        @output_dir || options[:output_dir]
      end

      def config_file
        @config_file || options[:config_file]
      end

      def generator(directories)
        opts = options.merge(:output_dir => output_dir, :config_file => config_file)
        (opts[:app_mode] ? ScGenerator : HtmlGenerator).new(directories, opts)
      end

      def update_repo(directories)
        return unless options[:update]
        return unless directories.length == 1
        directory = directories[0]

        puts "Updating repository...\n\n" if options[:verbose]

        if File.directory? directory and File.directory? "#{directory}/.git"
          Dir.chdir directory do
            run("git fetch", print_output)
            run("git rebase origin master", print_output)
          end
        end
      end

      def with_temp_output
        using_temp_dir = output_dir.nil? || output_dir.empty?

        if using_temp_dir
          require 'tempfile' # For Dir.tmpdir
          @output_dir = File.join(Dir.tmpdir, "docs#{rand(100000)}")
        end

        yield
      ensure
        if using_temp_dir
          FileUtils.rm_rf output_dir
          @output_dir = nil # Probably not necessary
        end
      end

  end
end

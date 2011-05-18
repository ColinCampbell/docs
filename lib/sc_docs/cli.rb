require 'thor'
require 'child_labor'
require 'sc_docs/server'

module ScDocs
  class CLI < Thor
    # --help and -h are already mapped to the help action, which is built in

    default_task :generate


    desc "generate", "Generates a build and deployes it to a web server"

    method_options %w(input_dir -i) => "", :type => :string
    method_options %w(verbose -v) => false, :type => :boolean
    method_options %w(--dont_update) => false, :type => :boolean
    method_options %w(--deploy -d) => false, :type => :boolean
    method_options %w(--project -p) => "sc_docs", :type => :string
    method_options %w(--output_dir -o) => "/Library/WebServer/Documents/", :type => :string
    method_options %w(--template -t) => nil, :type => :string
    method_options %w(--html -h) => false, :type => :boolean

    # The generate command will do the following:
    #
    # 1) Update the repository (if it's a repository)
    # 2) Generate a fixtures file
    # 3) Start sc-server for the doc viewer at port 4021
    def generate
      if not File.directory? options[:input_dir] and not File.file? options[:input_dir]
        puts "input_dir is not a valid directory or file."
        exit
      end

      base_path     = File.expand_path File.dirname(__FILE__)

      jsdoc_path    = File.expand_path("../../../vendor/jsdoc", __FILE__)
      template_path = options[:template] ?
                        File.expand_path(options[:template]) :
                        File.join(jsdoc_path, "templates", "sc_fixture")
      output_path   = options[:html] ?
                        File.expand_path("../tmp/docs", __FILE__) :
                        File.join(base_path, "docs", "apps", "docs", "fixtures")

      input_dir     = File.expand_path(options[:input_dir])

      output_file   = "class.js"
      class_name    = "Docs.Class"

      run_js_path   = File.join(jsdoc_path, "app", "run.js")

      deploy        = options[:deploy]
      project       = options[:project]

      if not File.directory? jsdoc_path
        puts "#{jsdoc_path} was not found."
        exit
      end

      if not File.file? run_js_path 
        puts "#{run_js_path} was not found. You can specify a path to it using -j"
        exit
      end

      # Prep
      FileUtils.rm_rf output_path
      FileUtils.mkdir_p output_path

      # Copy other files to output
      path = File.join(template_path, "output")
      if File.directory?(path)
        Dir["#{path}/*"].each{|p| FileUtils.cp_r(p, output_path) }
      end

      # Build command
      command = "#{run_js_path} -apsv -r=20 -t=#{template_path} #{input_dir} -d=#{output_path} -f=#{output_file} -l=#{class_name}"

      puts "Generating Documentation...\n\n";
     
      if not options[:dont_update]
        if options[:verbose]
          puts "\n------------------------------------"
          puts "Updating repository"
        end
        update_repo(input_dir, options[:verbose])
      end

      if options[:verbose]
        puts "\n------------------------------------"
        puts "Running command: #{command}"
      end
      Dir.chdir jsdoc_path

      #run(command, options[:verbose])
      cmd_output =  `#{command}`

      if options[:verbose]
        puts cmd_output
      end

      Dir.chdir base_path

      if deploy

        output_dir = options[:output_dir]

        if not File.directory? output_dir
          puts "#{output_dir} is not a valid directory."
          exit
        end

        perform_deploy(project, output_dir)

      elsif options[:html]

        Server.new(output_path).start

      else

        puts "\n------------------------------------"
        puts "Starting sc-server at port 4021..."

        Dir.chdir File.expand_path(File.join(base_path, "docs"))
        puts `sc-server --port 4021`

      end
    end


    def help
      shell.say <<-EOS.gsub(/^      /, '')
        USAGE: ./sc-docs [-h] [-v] --input_dir INPUT_DIRECTORY_PATH [--deploy] [-p PROJECT_NAME] [--ouput_dir] [--dont_update]

        sc-docs uses jsdoc-toolkit to parse a list of javascript files and generates 
        a fixtures file which can be dropped into the documentation viewer as-is. 

        sc-docs has built-in support for updating a git repository. If the input directory is
        a git repo, it will attempt to fetch, and then rebase against origin/master. If you would
        rather not do that, then specify --dont_update

        By only specifying an input_dir, sc-docs will start an instance of the doc viewer
        at port 4021. If you would rather generate a build and deploy it, then you need
        to specify the -d (deploy) and the -p (project name) options as well (see example)

        By default, sc-docs plays nicely with OS X and deploys to /Library/WebServer/Documents. If you
        would rather deploy to another location, you can specify that with the --output_dir or -o flag.

        Example:

          This example starts the doc viewer at port 4021

          ./sc-docs --input_dir ~/github/sproutcore/ 

          This example generates a build of the doc viewer and deploys it to /Library/WebServer/Documents

          ./sc-docs --input_dir ~/github/sproutcore/ 
                     -d -p sproutcore

        Author: Majd Taby
      EOS
    end

    private

    def perform_deploy(project_name, output_dir)
      base_path = Dir.pwd
      puts "base_path = #{base_path}"

      docs_app_dir = "#{base_path}/docs"

      docs_build_cmd = "./bin/sc-build -r --languages=en --build-targets=docs --build=#{project_name}"
      deploy_cmd = "cp -nr #{base_path}/docs/tmp/build/sc_docs #{output_dir}"

      rm_old_build_cmd = "rm -rf #{base_path}/docs/tmp"
      rm_old_deployment_cmd = "rm -rf #{output_dir}sc_docs/docs/en/#{project_name}"

      if not File.directory? output_dir
        puts "mkdir -p #{output_dir}"
        puts `mkdir -p #{output_dir}`
      end

      puts "\n------------------------------------"
      puts "Generating Build of Docs Viewer with new fixtures data: #{docs_build_cmd}"
      Dir.chdir docs_app_dir

      #puts rm_old_build_cmd
      puts `#{rm_old_build_cmd}`
      
      #puts docs_build_cmd
      puts `#{docs_build_cmd}`

      puts "\n------------------------------------"
      puts "Deploying Doc Viewer: #{deploy_cmd}"

      #puts rm_old_deployment_cmd
      puts `#{rm_old_deployment_cmd}`

      #puts deploy_cmd
      puts `#{deploy_cmd}`
    end

    def update_repo(input_dir, print_output = false)

      if File.directory? input_dir and File.directory? "#{input_dir}/.git"
        Dir.chdir input_dir
        run("git fetch", print_output)
        run("git rebase origin master", print_output)
      end

    end

    def run(command, output = false)
      #puts "--- Executing command: #{command}"
      ChildLabor.subprocess(command) do |task|
        task.wait

        stdout = task.read.strip
        stderr = task.read_stderr.strip

        if output
          with_padding do
            shell.say(stdout, :green) unless stdout.empty?
            shell.say(stderr, :red) unless stderr.empty?
          end
        end

        return stdout.empty? ? stderr : stdout
      end
    end
  end
end

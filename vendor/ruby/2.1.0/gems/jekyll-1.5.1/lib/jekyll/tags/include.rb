module Jekyll
  module Tags
    class IncludeTagError < StandardError
      attr_accessor :path

      def initialize(msg, path)
        super(msg)
        @path = path
      end
    end

    class IncludeTag < Liquid::Tag

      SYNTAX_EXAMPLE = "{% include file.ext param='value' param2='value' %}"

      VALID_SYNTAX = /([\w-]+)\s*=\s*(?:"([^"\\]*(?:\\.[^"\\]*)*)"|'([^'\\]*(?:\\.[^'\\]*)*)'|([\w\.-]+))/

      INCLUDES_DIR = '_includes'

      def initialize(tag_name, markup, tokens)
        super
        @file, @params = markup.strip.split(' ', 2);
        validate_params if @params
      end

      def parse_params(context)
        params = {}
        markup = @params

        while match = VALID_SYNTAX.match(markup) do
          markup = markup[match.end(0)..-1]

          value = if match[2]
            match[2].gsub(/\\"/, '"')
          elsif match[3]
            match[3].gsub(/\\'/, "'")
          elsif match[4]
            context[match[4]]
          end

          params[match[1]] = value
        end
        params
      end

      def validate_file_name(file)
        if file !~ /^[a-zA-Z0-9_\/\.-]+$/ || file =~ /\.\// || file =~ /\/\./
            raise ArgumentError.new <<-eos
Invalid syntax for include tag. File contains invalid characters or sequences:

	#{@file}

Valid syntax:

	#{SYNTAX_EXAMPLE}

eos
        end
      end

      def validate_params
        full_valid_syntax = Regexp.compile('\A\s*(?:' + VALID_SYNTAX.to_s + '(?=\s|\z)\s*)*\z')
        unless @params =~ full_valid_syntax
          raise ArgumentError.new <<-eos
Invalid syntax for include tag:

	#{@params}

Valid syntax:

	#{SYNTAX_EXAMPLE}

eos
        end
      end

      # Grab file read opts in the context
      def file_read_opts(context)
        context.registers[:site].file_read_opts
      end

      def retrieve_variable(context)
        if /\{\{([\w\-\.]+)\}\}/ =~ @file
          raise ArgumentError.new("No variable #{$1} was found in include tag") if context[$1].nil?
          context[$1]
        end
      end

      def render(context)
        dir = File.join(File.realpath(context.registers[:site].source), INCLUDES_DIR)

        file = retrieve_variable(context) || @file
        validate_file_name(file)

        path = File.join(dir, file)
        validate_path(path, dir, context.registers[:site].safe)

        begin
          partial = Liquid::Template.parse(source(path, context))

          context.stack do
            context['include'] = parse_params(context) if @params
            partial.render!(context)
          end
        rescue => e
          raise IncludeTagError.new e.message, File.join(INCLUDES_DIR, @file)
        end
      end

      def validate_path(path, dir, safe)
        if safe && !realpath_prefixed_with?(path, dir)
          raise IOError.new "The included file '#{path}' should exist and should not be a symlink"
        elsif !File.exist?(path)
          raise IOError.new "Included file '#{path}' not found"
        end
      end

      def realpath_prefixed_with?(path, dir)
        File.exist?(path) && File.realpath(path).start_with?(dir)
      end

      def blank?
        false
      end

      # This method allows to modify the file content by inheriting from the class.
      def source(file, context)
        File.read_with_options(file, file_read_opts(context))
      end
    end
  end
end

Liquid::Template.register_tag('include', Jekyll::Tags::IncludeTag)

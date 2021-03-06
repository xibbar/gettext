# -*- coding: utf-8 -*-
#
# Copyright (C) 2012  Kouhei Sutou <kou@clear-code.com>
# Copyright (C) 2012  Haruka Yoshihara <yoshihara@clear-code.com>
#
# License: Ruby's or LGPL
#
# This library is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "iconv"
require "locale"
require "gettext/tools/xgettext"

class TestToolsXGetText < Test::Unit::TestCase
  include GetTextTestUtils

  def setup
    @xgettext = GetText::Tools::XGetText.new
    @now = Time.parse("2012-08-19 18:10+0900")
    stub(@xgettext).now {@now}
  end

  setup :setup_tmpdir
  teardown :teardown_tmpdir

  setup
  def setup_paths
    @rb_file_path = File.join(@tmpdir, "lib", "xgettext.rb")
    @pot_file_path = File.join(@tmpdir, "po", "xgettext.pot")
    @rhtml_file_path = File.join(@tmpdir, "templates", "xgettext.rhtml")
    FileUtils.mkdir_p(File.dirname(@rb_file_path))
    FileUtils.mkdir_p(File.dirname(@pot_file_path))
    FileUtils.mkdir_p(File.dirname(@rhtml_file_path))
  end

  def test_relative_reference
    File.open(@rb_file_path, "w") do |rb_file|
      rb_file.puts(<<-EOR)
_("Hello")
EOR
    end

    @xgettext.run("--output", @pot_file_path, @rb_file_path)

    assert_equal(<<-EOP, File.read(@pot_file_path))
#{header}
#: ../lib/xgettext.rb:1
msgid "Hello"
msgstr ""
EOP
  end

  class TestEncoding < self
    def test_different_encoding_from_current_locale
      need_encoding

      rhtml = <<-EOR
<%#-*- coding: sjis -*-%>
<html>
<head>
<title></title>
</head>
<body>
<h1><%= _("わたし") %></h1>
</body>
</html>
EOR
      File.open(@rhtml_file_path, "w") do |rhtml_file|
        rhtml_file.puts(encode(rhtml, "sjis"))
      end

      @xgettext.run("--output", @pot_file_path, @rhtml_file_path)

      encoding = "UTF-8"
      pot_content = File.read(@pot_file_path)
      set_encoding(pot_content, encoding)
      expected_content = <<-EOP
#{header}
#: ../templates/xgettext.rhtml:7
msgid "わたし"
msgstr ""
EOP
      expected_content = encode(expected_content, encoding)
      assert_equal(expected_content, pot_content)
    end

    def test_multiple_encodings
      need_encoding

      File.open(@rb_file_path, "w") do |rb_file|
        rb_file.puts(encode(<<-EOR, "euc-jp"))
# -*- coding: euc-jp -*-
_("こんにちは")
EOR
      end

      File.open(@rhtml_file_path, "w") do |rhtml_file|
        rhtml_file.puts(encode(<<-EOR, "cp932"))
<%# -*- coding: cp932 -*-%>
<h1><%= _("わたし") %></h1>
EOR
      end

      @xgettext.run("--output", @pot_file_path, @rb_file_path, @rhtml_file_path)

      encoding = "UTF-8"
      pot_content = File.read(@pot_file_path)
      set_encoding(pot_content, encoding)
      expected_content = <<-EOP
#{header}
#: ../lib/xgettext.rb:2
msgid "こんにちは"
msgstr ""

#: ../templates/xgettext.rhtml:2
msgid "わたし"
msgstr ""
EOP
      expected_content = encode(expected_content, encoding)
      assert_equal(expected_content, pot_content)
    end
  end

  class TestCommandLineOption < self
    def test_package_name
      File.open(@rb_file_path, "w") do |rb_file|
        rb_file.puts(":hello")
      end

      package_name = "test-package"
      @xgettext.run("--output", @pot_file_path,
                    "--package-name", package_name,
                    @rb_file_path)

      options = {:package_name => package_name}
      expected_header = "#{header(options)}\n"
      assert_equal(expected_header, File.read(@pot_file_path))
    end

    def test_package_version
      File.open(@rb_file_path, "w") do |rb_file|
        rb_file.puts(":hello")
      end

      package_version = "1.2.3"
      @xgettext.run("--output", @pot_file_path,
                    "--package-version", package_version,
                    @rb_file_path)

      options = {:package_version => package_version}
      expected_header = "#{header(options)}\n"
      assert_equal(expected_header, File.read(@pot_file_path))
    end

    def test_report_msgid_bugs_to
      File.open(@rb_file_path, "w") do |rb_file|
        rb_file.puts(":hello")
      end

      msgid_bugs_address = "me@example.com"
      @xgettext.run("--output", @pot_file_path,
                    "--msgid-bugs-address", msgid_bugs_address,
                    @rb_file_path)

      options = {:msgid_bugs_address => msgid_bugs_address}
      expected_header = "#{header(options)}\n"
      assert_equal(expected_header, File.read(@pot_file_path))
    end

    def test_copyright_holder
      File.open(@rb_file_path, "w") do |rb_file|
        rb_file.puts(":hello")
      end

      copyright_holder = "me"
      @xgettext.run("--output", @pot_file_path,
                    "--copyright-holder", copyright_holder,
                    @rb_file_path)

      options = {:copyright_holder => copyright_holder}
      expected_header = "#{header(options)}\n"
      assert_equal(expected_header, File.read(@pot_file_path))
    end

    def test_to_code
      need_encoding

      File.open(@rb_file_path, "w") do |rb_file|
        rb_file.puts(<<-EOR)
# -*- coding: utf-8 -*-

_("わたし")
EOR
      end

      output_encoding = "EUC-JP"
      @xgettext.run("--output", @pot_file_path,
                    "--output-encoding", output_encoding,
                    @rb_file_path)

      actual_pot = File.read(@pot_file_path)
      set_encoding(actual_pot, output_encoding)

      options = {:to_code => output_encoding}
      expected_pot = <<-EOP
#{header(options)}
#: ../lib/xgettext.rb:3
msgid "わたし"
msgstr ""
EOP
      expected_pot = encode(expected_pot, output_encoding)

      assert_equal(expected_pot, actual_pot)
    end
  end

  class TestAddParser < self
    setup
    def setup_default_parsers
      @default_parsers = default_parsers.dup
    end

    teardown
    def teardown_default_parsers
      default_parsers.replace(@default_parsers)
    end

    def test_class_method
      GetText::Tools::XGetText.add_parser(mock_html_parser)
      xgettext = GetText::Tools::XGetText.new
      xgettext.parse(["index.html"])
    end

    def test_instance_method
      @xgettext.add_parser(mock_html_parser)
      @xgettext.parse(["index.html"])
    end

    private
    def default_parsers
      GetText::Tools::XGetText.module_eval("@@default_parsers")
    end

    def mock_html_parser
      html_parser = Object.new
      mock(html_parser).target?("index.html") {true}
      mock(html_parser).parse("index.html") {[]}
      html_parser
    end
  end

  class TestRGetText < self
    def setup
      @now = Time.now
      @warning_message = "Warning: This method is obsolete. " +
                           "Please use GetText::Tools::XGetText.run."
    end

    def test_warning
      mock(GetText::RGetText).warn(@warning_message) {}

      File.open(@rb_file_path, "w") do |rb_file|
      end
      GetText::RGetText.run(@rb_file_path, @pot_file_path)
    end

    class TestArguments < self
      def test_input_file_and_output_file
        stub(GetText::RGetText).warn(@warning_message) {}

        File.open(@rb_file_path, "w") do |rb_file|
          rb_file.puts(<<-EOR)
_("Hello")
EOR
        end
        GetText::RGetText.run(@rb_file_path, @pot_file_path)

        assert_equal(expected_pot_content, File.read(@pot_file_path))
      end

      def test_argv
        stub(GetText::RGetText).warn(@warning_message) {}

        File.open(@rb_file_path, "w") do |rb_file|
          rb_file.puts(<<-EOR)
_("Hello")
EOR
        end

        ARGV.replace([@rb_file_path, "--output",  @pot_file_path])
        GetText::RGetText.run

        assert_equal(expected_pot_content, File.read(@pot_file_path))
      end

      private
      def expected_pot_content
        <<-EOP
#{header}
#: ../lib/xgettext.rb:1
msgid "Hello"
msgstr ""
EOP
      end
    end
  end

  private
  def header(options=nil)
    options ||= {}
    package_name = options[:package_name] || "PACKAGE"
    package_version = options[:package_version] || "VERSION"
    msgid_bugs_address = options[:msgid_bugs_address] || ""
    copyright_holder = options[:copyright_holder] ||
                         "THE PACKAGE'S COPYRIGHT HOLDER"
    output_encoding = options[:to_code] || "UTF-8"

    time = @now.strftime("%Y-%m-%d %H:%M%z")
    <<-"EOH"
# SOME DESCRIPTIVE TITLE.
# Copyright (C) YEAR #{copyright_holder}
# This file is distributed under the same license as the #{package_name} package.
# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.
#
#, fuzzy
msgid ""
msgstr ""
"Project-Id-Version: #{package_name} #{package_version}\\n"
"Report-Msgid-Bugs-To: #{msgid_bugs_address}\\n"
"POT-Creation-Date: #{time}\\n"
"PO-Revision-Date: #{time}\\n"
"Last-Translator: FULL NAME <EMAIL@ADDRESS>\\n"
"Language-Team: LANGUAGE <LL@li.org>\\n"
"Language: \\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=#{output_encoding}\\n"
"Content-Transfer-Encoding: 8bit\\n"
"Plural-Forms: nplurals=INTEGER; plural=EXPRESSION;\\n"
EOH
  end
end

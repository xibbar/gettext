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

require "gettext/tools/poparser"

class TestPOParser < Test::Unit::TestCase
  def test_msgstr_not_existing
    po_file = create_po_file(<<-EOP)
msgid "Hello"
msgstr ""
EOP
    messages = parse_po_file(po_file, MO.new)

    assert_equal(nil, messages["Hello"])
  end

  def test_empty_msgstr_for_msgid_plural
    po_file = create_po_file(<<-EOP)
msgid "He"
msgid_plural "They"
msgstr[0] ""
msgstr[1] ""
EOP
    messages = parse_po_file(po_file, MO.new)

    assert_true(messages.has_key?("He\000They"))
    assert_equal(nil, messages["He\000They"])
  end

  class TestPoData < self
    def test_comment
      po_file = create_po_file(<<-EOP)
#: file.rb:10
msgid "hello"
msgstr "bonjour"
EOP
      entries = parse_po_file(po_file)
      assert_true(entries.msgids.include?("hello"))
      assert_equal("bonjour", entries["hello"])
      assert_equal("#: file.rb:10", entries.comment("hello"))
    end

    def test_msgctxt
      po_file = create_po_file(<<-EOP)
msgctxt "pronoun"
msgid "he"
msgstr "il"
EOP
      entries = parse_po_file(po_file)
      assert_true(entries.msgids.include?("pronoun\004he"))
      assert_equal("il", entries["pronoun\004he"])
    end

    def test_msgid_plural
      po_file = create_po_file(<<-EOP)
msgid "he"
msgid_plural "they"
msgstr[0] "il"
msgstr[1] "ils"
EOP
      entries = parse_po_file(po_file)

      assert_true(entries.msgids.include?("he\000they"))
      assert_equal("il\000ils", entries["he\000they"])
    end

    def test_msgctxt_and_msgid_plural
      po_file = create_po_file(<<-EOP)
msgctxt "pronoun"
msgid "he"
msgid_plural "them"
msgstr[0] "il"
msgstr[1] "ils"
EOP
      entries = parse_po_file(po_file)
      assert_true(entries.msgids.include?("pronoun\004he\000them"))
      assert_equal("il\000ils", entries["pronoun\004he\000them"])
    end

    private
    def parse_po_file(po_file)
      super(po_file, GetText::Tools::MsgMerge::PoData.new)
    end
  end

  class TestPO < self
    def test_msgstr
      po_file = create_po_file(<<-EOP)
# This is the comment.
#: file.rb:10
msgid "hello"
msgstr "bonjour"
EOP
      entries = parse_po_file(po_file)
      assert_true(entries.has_key?(nil, "hello"))
      assert_equal("bonjour", entries["hello"].msgstr)
    end

    def test_references
      po_file = create_po_file(<<-EOP)
# This is the comment.
#: file.rb:10
msgid "hello"
msgstr "bonjour"
EOP
      entries = parse_po_file(po_file)
      assert_true(entries.has_key?(nil, "hello"))
      assert_equal(["file.rb:10"], entries["hello"].references)
    end

    def test_translator_comment
      po_file = create_po_file(<<-EOP)
# This is the translator comment.
msgid "hello"
msgstr "bonjour"
EOP
      entries = parse_po_file(po_file)
      assert_true(entries.has_key?(nil, "hello"))
      entry = entries["hello"]
      assert_equal("This is the translator comment.", entry.translator_comment)
    end

    def test_extracted_comment
      po_file = create_po_file(<<-EOP)
#. This is the extracted comment.
msgid "hello"
msgstr "bonjour"
EOP
      entries = parse_po_file(po_file)
      assert_true(entries.has_key?(nil, "hello"))
      entry = entries["hello"]
      assert_equal("This is the extracted comment.", entry.extracted_comment)
    end

    def test_flag
      po_file = create_po_file(<<-EOP)
#, flag
msgid "hello"
msgstr "bonjour"
EOP
      entries = parse_po_file(po_file)
      assert_true(entries.has_key?(nil, "hello"))
      assert_equal("flag", entries["hello"].flag)
    end

    def test_previous
      po_file = create_po_file(<<-EOP)
#| msgctxt Normal
#| msgid He
#| msgid_plural Them
msgid "he"
msgid_plural "them"
msgstr[0] "il"
msgstr[1] "ils"
EOP
      expected_previous = "msgctxt Normal\n" +
                                  "msgid He\n" +
                                  "msgid_plural Them"
      entries = parse_po_file(po_file)
      assert_true(entries.has_key?(nil, "he"))
      assert_equal(expected_previous, entries["he"].previous)
    end

    def test_msgid_plural
      po_file = create_po_file(<<-EOP)
# This is the comment.
#: file.rb:10
msgid "he"
msgid_plural "them"
msgstr[0] "il"
msgstr[1] "ils"
EOP
      entries = parse_po_file(po_file)
      assert_true(entries.has_key?(nil, "he"))
      assert_equal("them", entries["he"].msgid_plural)
      assert_equal("il\000ils", entries["he"].msgstr)
    end

    def test_msgctxt
      po_file = create_po_file(<<-EOP)
# This is the comment.
#: file.rb:10
msgctxt "pronoun"
msgid "he"
msgstr "il"
EOP
      entries = parse_po_file(po_file)
      assert_true(entries.has_key?("pronoun", "he"))
      assert_equal("pronoun", entries["pronoun", "he"].msgctxt)
    end

    def test_msgctxt_with_msgid_plural
      po_file = create_po_file(<<-EOP)
# This is the comment.
#: file.rb:10
msgctxt "pronoun"
msgid "he"
msgid_plural "them"
msgstr[0] "il"
msgstr[1] "ils"
EOP
      entries = parse_po_file(po_file)
      assert_true(entries.has_key?("pronoun", "he"))
      assert_equal("pronoun", entries["pronoun", "he"].msgctxt)
      assert_equal("them", entries["pronoun", "he"].msgid_plural)
      assert_equal("il\000ils", entries["pronoun", "he"].msgstr)
    end

    def test_fuzzy
      po_file = create_po_file(<<-EOP)
#, fuzzy
#: file.rb:10
msgid "hello"
msgstr "bonjour"
EOP
      entries = parse_po_file(po_file, :ignore_fuzzy => false)

      assert_true(entries.has_key?("hello"))
      assert_equal("fuzzy", entries["hello"].flag)
    end

    private
    def parse_po_file(po_file, options={:ignore_fuzzy => true})
      ignore_fuzzy = options[:ignore_fuzzy]
      parser = GetText::POParser.new
      parser.ignore_fuzzy = ignore_fuzzy
      parser.parse_file(po_file.path, PO.new)
    end
  end

  private
  def create_po_file(content)
    po_file = Tempfile.new("hello.po")
    po_file.print(content)
    po_file.close
    po_file
  end

  def parse_po_file(po_file, parsed_entries)
    parser = GetText::POParser.new
    parser.parse_file(po_file.path, parsed_entries)
  end

  class FuzzyTest < self
    def setup
      @po = <<-EOP
#, fuzzy
msgid "Hello"
msgstr "Bonjour"
EOP
      @po_file = Tempfile.new("hello.po")
      @po_file.print(@po)
      @po_file.close
    end

    class IgnoreTest < self
      def test_report_warning
        mock($stderr).print("Warning: fuzzy message was ignored.\n")
        mock($stderr).print("  #{@po_file.path}: msgid 'Hello'\n")
        messages = parse do |parser|
          parser.ignore_fuzzy = true
          parser.report_warning = true
        end
        assert_nil(messages["Hello"])
      end

      def test_not_report_warning
        dont_allow($stderr).print("Warning: fuzzy message was ignored.\n")
        dont_allow($stderr).print("  #{@po_file.path}: msgid 'Hello'\n")
        messages = parse do |parser|
          parser.ignore_fuzzy = true
          parser.report_warning = false
        end
        assert_nil(messages["Hello"])
      end
    end

    class NotIgnore < self
      def test_report_warning
        mock($stderr).print("Warning: fuzzy message was used.\n")
        mock($stderr).print("  #{@po_file.path}: msgid 'Hello'\n")
        messages = parse do |parser|
          parser.ignore_fuzzy = false
          parser.report_warning = true
        end
        assert_equal("Bonjour", messages["Hello"])
      end

      def test_not_report_warning
        dont_allow($stderr).print("Warning: fuzzy message was used.\n")
        dont_allow($stderr).print("  #{@po_file.path}: msgid 'Hello'\n")
        messages = parse do |parser|
          parser.ignore_fuzzy = false
          parser.report_warning = false
        end
        assert_equal("Bonjour", messages["Hello"])
      end
    end

    private
    def parse
      parser = GetText::POParser.new
      class << parser
        def _(message_id)
          message_id
        end
      end
      messages = MO.new
      yield parser
      parser.parse_file(@po_file.path, messages)
      messages
    end
  end
end

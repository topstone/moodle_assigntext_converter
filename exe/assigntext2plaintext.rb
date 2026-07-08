# -*- coding: utf-8 -*-
#
# 使い方:
#   ruby assigntext2plaintext.rb YYYYMMDD "任意の文字列" file1.html file2.html ...
#
# 例:
#   ruby assigntext2plaintext.rb 20260706 "zzz" ./*.html
#
# 各 html ファイルの p 要素・div 要素の中身(テキストのみ)を抽出し、
#   <元ファイル名(拡張子除く)>_<YYYYMMDD>.txt
# という名前でカレントディレクトリに出力する。
#
# 出力内容(区切り線の前後・各要素の間には必ず空行が入る):
#   <第2引数の文字列>
#
#   ====
#
#   <1つ目の p/div の中身>
#
#   <2つ目の p/div の中身>
#   ...

require 'cgi'

def show_usage
  puts <<~USAGE
    使い方: ruby #{File.basename(__FILE__)} YYYYMMDD 文字列 file1.html [file2.html ...]
    例    : ruby #{File.basename(__FILE__)} 20260706 "zzz" ./*.html
  USAGE
end

date_arg  = ARGV[0]
label_arg = ARGV[1]
file_args = ARGV[2..] || []

# 第1引数が YYYYMMDD 形式かチェック
unless date_arg =~ /\A\d{8}\z/
  show_usage
  exit 1
end

if label_arg.nil? || file_args.empty?
  show_usage
  exit 1
end

# Windows の cmd.exe 等でワイルドカードが展開されない場合に備えて自前で glob 展開
html_files = file_args.flat_map do |pattern|
  if pattern =~ /[*?\[\]]/
    Dir.glob(pattern)
  else
    [pattern]
  end
end.uniq

if html_files.empty?
  puts "対象の html ファイルが見つかりませんでした。"
  exit 1
end

# buffer(タグを含む生のHTML断片)からテキストのみを取り出す
def buffer_to_text(buffer)
  text = buffer.dup
  text = text.gsub(/<br\s*\/?>/i, "\u0001")   # <br> は一旦プレースホルダに
  text = text.gsub(/<[^>]+>/, '')              # 残りのタグを除去
  text = CGI.unescapeHTML(text)                 # &amp; 等のエンティティを復元
  text = text.gsub(/[ \t\r\n]+/, ' ')          # ソース上の改行・連続空白を1つの半角空白に
  text = text.gsub("\u0001", "\n")             # プレースホルダを改行に戻す
  text.split("\n").map(&:strip).reject(&:empty?).join("\n")
end

# html文字列から「入れ子になっていない最上位の」p要素・div要素の中身を順番に抽出する
# (例: <div><p>A</p></div> の場合は div 側で1件としてまとめて抽出し、重複させない)
def extract_blocks(html)
  # コメント・script・style は除外
  cleaned = html.gsub(/<!--.*?-->/m, '')
  cleaned = cleaned.gsub(/<(script|style)\b[^>]*>.*?<\/\1>/mi, '')

  tokens = cleaned.scan(/<[^>]+>|[^<]+/)

  items = []
  capturing   = false
  target_name = nil
  depth       = 0
  buffer      = +""

  tokens.each do |tok|
    if tok.start_with?('<')
      if tok =~ /\A<\s*\/\s*([a-zA-Z0-9]+)/
        closing = true
        name = $1.downcase
      elsif tok =~ /\A<\s*([a-zA-Z0-9]+)/
        closing = false
        name = $1.downcase
      else
        next
      end

      unless capturing
        if !closing && (name == 'p' || name == 'div')
          capturing   = true
          target_name = name
          depth       = 1
          buffer      = +""
        end
        next
      end

      if name == target_name
        if closing
          depth -= 1
          if depth.zero?
            items << buffer
            capturing   = false
            target_name = nil
            buffer      = +""
          else
            buffer << tok
          end
        else
          depth += 1
          buffer << tok
        end
      else
        buffer << tok
      end
    else
      buffer << tok if capturing
    end
  end

  items.map { |raw| buffer_to_text(raw) }.reject(&:empty?)
end

html_files.each do |path|
  unless File.file?(path)
    warn "スキップ(ファイルが存在しません): #{path}"
    next
  end

  html  = File.read(path, encoding: 'UTF-8')
  items = extract_blocks(html)

  base     = File.basename(path, File.extname(path))
  out_name = "#{base}_#{date_arg}.txt"
  out_path = File.join(Dir.pwd, out_name)  # 出力は必ずカレントディレクトリ

  parts   = [label_arg, "===="] + items
  content = parts.join("\n\n") + "\n"

  File.write(out_path, content, encoding: 'UTF-8')
  puts "出力しました: #{out_path}"
end

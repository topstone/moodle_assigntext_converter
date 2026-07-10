# moodle_assigntext_converter

local_assignsubmission_download の出力を変換

## 使い方

* local_assignsubmission_download (https://github.com/academic-moodle-cooperation/moodle-local_assignsubmission_download) を download し install
* online text だけの課題 (assignment) を用意
* 「さらに」→「提出リネームダウンロード」
* 命名規則は「[username]」のみ
* extract し、その folder の中に「txt」folder を作りそこで cli
* ruby .\assigntext2plaintext.rb 20260706 以下は○○です。 ../*.html




# 用 Markdown 来写 LaTeX 文档

> 一直被导师批评不写文档.. 我也想写啊..

LaTeX 最让人讨厌的就是本人的可读性差, 需要编译. 自称将内容和排版分开, 
让作者专注内容是其优点, 但是实际上排版需要的控制符号输入麻烦,
代码中的下划线还要转义, 每次想插入图片时还得去查手册. 感觉并没有达到其宣称的效果.

现在 Web 时代, pdf 也越来越显得不受待见, 也许能够通过修改 LaTeX 的编译模板使其
适合不同设备屏幕, 但是哪有 HTML 方便.

现在 MarkDown 几乎成了程序员文档的标准. 各种静态博客也支持将 Markdown 作为其
源文件. 在 GitHub 上 MarkDown 直接能够被翻译成 HTML.

于是想到把 Markdown 翻译成 LaTeX... 早就知道 Pandoc 的, 但是没有用起来.
这里是第一次尝试 MarkDown 与 LaTeX 混排.

下面介绍 Pandoc Mardkown 和这个目录 `ksm-doc` 的使用方法.

## Pandoc

[`pandoc`](https://pandoc.org/) 是一个用于文档格式转换的 Huskell 和命令行工具,
这里单纯把它当做把 Markdown 翻译成 LaTeX 的工具.

`pandoc text.md -o text.tex`

[Pandoc Marddown](https://pandoc.org/MANUAL.html#pandocs-markdown)
是 Markdown 的一种方言, 增加了一些扩展. 最重要的是支持直接使用 LaTeX 命令.
即在 `.md` 文档中写的 LaTeX 宏命令会直接复制到生成的 `.tex` 文件中.

`pandoc` 生成的 `.tex` 会用到一些宏包, 所以我加上 `--standalone` 参数后, 
将生成的 `.tex` 文件的 preamber 复制出来放在 `preamber.tex` 中了.

## marktex

这样的做法就叫 Marktex 吧. 参见 [Makefile](../Makefile).

目前所有的 `.md` 文件都在根目录下, 编译时把从 `.md` 生成的 `.tex` 文件复制
到 `latex/` 目录下, 把手写的 `.tex` 也复制过去. 在 `latex/` 目录下编译.

目前 Makefile 还比较简单, 今后如果增加了子目录再改进吧.





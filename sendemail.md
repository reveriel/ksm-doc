
下文原文[How to Use git
send-email](https://www.freedesktop.org/wiki/Software/PulseAudio/HowToUseGitSendEmail/)
是 [pulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/)
的 wiki 页面. 

# 如何使用 git send-email

发送补丁的首选方式是通过电子邮件，使用git
send-email（有关发送补丁的更多信息，请访问[社区](https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/Community/)页面）。
本页介绍了如何使用git send-email。

## 安装 send-email

您可能已经安装了git，但这还不足以让 send-email 命令可用。
您可以通过运行`git send-email --help`来检查发送电子邮件是否可用。
如果它显示send-email的手册页，则可以使用 send-email。
否则，您需要安装send-email命令。 您的发行版可能有一个包;
在Debian/Ubuntu 上，包名是“git-email”。

## 配置您的姓名和电子邮件地址

你应该告诉git你的名字和电子邮件地址。 您可能已经这样做了，但如果没有，请运行以下命令：

```
git config --global user.name "My Name"
git config --global user.email "myemail@example.com"
```

## 配置邮件发送选项

git send-email通过SMTP服务器发送电子邮件，因此您需要配置服务器参数。 请参阅您的电子邮件提供商文档以查找正确的参数。 这就是我配置邮件设置的方法：

```
git config --global sendemail.smtpencryption tls
git config --global sendemail.smtpserver mail.messagingengine.com
git config --global sendemail.smtpuser tanuk@fastmail.fm
git config --global sendemail.smtpserverport 587
git config --global sendemail.smtppass hackme
```

将密码存储在git配置文件中显然存在安全风险。 配置密码不是必需的。 如果没有配置，git send-email会在每次使用命令时询问它。

## 配置默认目标地址

对于PulseAudio，补丁应该发送到我们的邮件列表。 为了避免必须记住它并一直重新输入，您可以配置git send-email默认使用的地址。 由于您可能使用git为许多项目做出贡献，因此全局设置此选项没有意义，因此我们只会将其设置在PulseAudio代码的克隆中。

```
git config sendemail.to pulseaudio-discuss@lists.freedesktop.org
```

## 避免向自己发送邮件

默认情况下，git send-email会将补丁的作者添加到抄送：(Cc:)字段。
当您发送自己编写的补丁时，这意味着每个补丁的副本将被发送到您的电子邮件地址。
如果您不喜欢这样，可以通过设置此配置选项来避免这种情况
（有关可能值的完整列表，请参阅“git send-email --help”）：

```
git config --global sendemail.suppresscc self
```

## 使用send-email命令

有关完整参考，请参阅“git send-email --help”。我将在这里仅介绍基本用法。

在发送补丁之前，git send-email
会询问一些问题（更新：更新的git版本会提出更少的问题，有时甚至没有问题）。大多数问题都有一个合理的默认值，用方括号表示。只需按Enter键即可使用默认值。如果您不想使用默认答案，请键入问题的答案。问题是：

- 这些电子邮件应该来自谁？
  - 这将用作“From”标题。您之前应该已经配置了您的姓名和电子邮件地址，因此默认设置通常是正确的。
- 谁应该将电子邮件发送给谁？
  - 如上所述，补丁应发送到我们的邮件列表：pulseaudio-discuss@lists.freedesktop.org
- 消息ID将用作第一封电子邮件的In-Reply-To？
  - 这通常应该是空的。不要发送补丁作为对常规讨论的回复，这使得更难跟踪补丁。
- 发送此邮件？
  - 邮件标题在问题上方可见，因此您可以检查所有内容是否正常。

### 在当前分支中发送最后一次提交：

```
git send-email -1
```

发送一些其他提交：

```
git send-email -1 <commit reference>
```

### 发送多个补丁

在当前分支中发送最后10个提交：

```
git send-email -10 --cover-letter --annotate
```

`--cover-letter` 选项创建一个额外的邮件，将在实际的补丁邮件之前发送。
您可以在 cover letter 中添加对补丁集的一些介绍。
如果需要解释补丁，请务必在提交消息中包含解释，因为 cover letter 文本不会记录在git历史记录中。
如果您认为没有必要进行任何介绍或解释，那么默认 cover letter
中只包含 git 短 log，并且只将“主题”标题设置为合理的内容。

`--annotate` 选项导致为每个邮件启动编辑器，允许您编辑邮件。 该选项始终需要，以便您可以编辑
cover letter 的“主题”标题。

### 添加补丁版本信息

默认情况下，补丁邮件在主题中将具有 “[PATCH]”
（或“[PATCH n / m]”，其中n是补丁的序列号，m是补丁集中补丁的总数）。
发送补丁的更新版本时，应指明版本：“[PATCH v2]”或“[PATCH v2 n / m]”。 
为此，请使用`-v` 选项。
这是一个示例（您可能需要添加 `--annotate` 以在补丁中添加有关新版本中更改内容的注释）：

```
git send-email -v2 -1
```

### 更改或修改主题中的[PATCH]标签

可以使用 `--subject-prefix` 更改默认的“[PATCH]”标记。
这在发送 `pavucontrol` 或 `paprefs` 补丁时尤其有用，
因为主题应该注意补丁是否适用于main pulseaudio 库以外的其他git库。

例如：


```
# Using "[PATCH pavucontrol]" as the tag is a good way to indicate
# that the patch is meant for pavucontrol.
git send-email -1 --subject-prefix="PATCH pavucontrol"
```

### 向补丁邮件添加额外备注

有时，使用一些不应包含在提交消息中的注释来注释补丁是很方便的。
例如，有人可能想要在补丁中写“我不确定是否应该提交它，因为......”，
但是文本在提交消息(commit message)中没有意义。
这样的消息可以写在提交消息之后的每个补丁中的三个破折号“---”下面。 
使用带有git send-email 的 `--annotate` 选项可以在邮件发送之前编辑邮件。


### 分两步格式化补丁和发送补丁

可以先运行“git format-patch”来创建文本文件
（使用`-o`选项来选择存储文本文件的目录），然后检查和编辑这些文件,
而不是 在 send-email 时使用 `--annotate`选项。
检查完成后，可以使用“git send-email”（不带-1选项）发送它们。





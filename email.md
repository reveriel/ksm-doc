
# 发送和接受 email

参考 kernel的 文档 [Email clients info for Linux](https://www.kernel.org/doc/html/v4.11/process/email-clients.html)

## 用 git send-eamil 发送邮件

见 [git send-email](git_send_email.md)

## mutt

参考 arch 的 wiki [mutt](https://wiki.archlinux.org/index.php/mutt)

这个可以收发邮件.

把这个 模板配置放在 `~/.muttrc`, 下载 `mutt`, 直接运行就行了.

```
set folder      = imaps://imap.gmail.com/
set imap_user   = your.username@gmail.com
set imap_pass   = your-imap-password
set spoolfile   = +INBOX
mailboxes       = +INBOX

# Store message headers locally to speed things up.
# If hcache is a folder, Mutt will create sub cache folders for each account which may speeds things up even more.
set header_cache = ~/.cache/mutt

# Store messages locally to speed things up, like searching message bodies.
# Can be the same folder as header_cache.
# This will cost important disk usage according to your e-mail amount.
set message_cachedir = "~/.cache/mutt"

# Specify where to save and/or look for postponed messages.
set postponed = +[Gmail]/Drafts

# Allow Mutt to open a new IMAP connection automatically.
unset imap_passive

# Keep the IMAP connection alive by polling intermittently (time in seconds).
set imap_keepalive = 300

# How often to check for new mail (time in seconds).
set mail_check = 120

# where the mail is saved
save-hook . ~/Mail/gx
```









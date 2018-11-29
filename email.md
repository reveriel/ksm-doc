
# 发送和接受 email

参考 kernel的 文档 [Email clients info for Linux](https://www.kernel.org/doc/html/v4.11/process/email-clients.html)

## 用 git send-email 发送邮件

见 [git send-email](git_send_email.md)


### git send-email 加上 proxy

gmail 在国内有时候连不上. 发邮件的服务器 smtp.gmail.com 连不上就
发不出去, 这个不是 HTTP 协议, 而是 SMTP , 所以可能网页上能够收发邮件但是
命令行发布出去.

参考 [blog1](https://mine260309.me/archives/1656) [blog2](https://www.smitechow.com/2018/10/git-send-email-use-proxy.html)
. 使用 msmtp + proxychains. 我发现只用 proxychains 就行了.

```
sudo apt install proxychains
```

```
vim /etc/proxychains.conf
```

`proxychains.conf`:
```
[ProxyList]
http 192.168.56.1 1087
```

我的是 http 代理, host 机器上的 shadowsocks 分享出来的.
发邮件的机器是 virtualbox 里面的 Ubuntu.

```
proxychains git send-email .....
```

这样才能发出去.


## mutt

参考 arch 的 wiki [mutt](https://wiki.archlinux.org/index.php/mutt)

这个可以收发邮件. 我用这个来在命令行收邮件, 把 patch 保存成文本.

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







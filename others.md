# 测试

在 Linux 上内存去重的机会,

## mem trace. 全系统模拟

Ritt 开发的工具, 基于一个 cpu 模拟器, 能够记录模拟 cpu 的所有读写操作.
操作系统插桩. 使用特殊 cpu 指令,
传递 task 信息(包括, 正在运行的进程, task 创建与结束, memory
map, ) 这样能够
这允许在任何时间检查内存，用精确的信息注释，该过程已经映射了哪些页面帧.
文件页包括其文件名信息.  Ritt 的工具提供了 GUI.

记录所有读写时间信息能够做离线分析, 可以利用未来的信息做到最优的内存去重算法.
并尝试预测未来, 预测页面是否会被分享.

但是太慢了. 估计 slowdown 5000 倍以上.

## named merging

合并文件页 "named merging". 加到 KSM 上.

由于缺少抽象，在Linux中难以共享文件页。 目前在内核中没有抽象可以处理包含多个
inode ,即不同的文件, 内容的一个页面帧。  文件系统代码获取指向 page struct
 传递到其函数中, 文件系统然后需要找到相应的inode（通过 page->mapping
 ，直接指向它）和偏移。
 page->mapping 被一些驱动直接使用,  kernel 代码默认这些page frames
 是可以直接被 文件系统页面写的, 例如 DMA 请求就是直接作用在 page frames 上的,
这导致拦截 对文件页的写, 以实现 COW 变得很困难. 除非有一个 可编程的 IO MMU
能够 trap 写操作.

## dump process mem on linux

通过 /proc/pid/mem. 使用读写文件的方式读写进程的内存.

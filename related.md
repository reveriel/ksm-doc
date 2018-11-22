# 相关工作{#:sec:related}

本节介绍内存去重的相关工作.


\cite

## 安全相关


\cite{suzaki2011threat}内存去重对于Guest操作系统的威胁. 利用内存访问时间的差异.
被去重的页面需要通过 写时复制机制重新创建. 论文使用 KSM + KVM 环境, 攻击可以发现
机器上运行的sshd, apache2, IE6, Firefox 软件, 甚至 Firefox 正在下载的文件.


\cite{bosman2016dedup}在Windows 系统中, 内存去重是默认打开的特性. 之前的工作
利用 CoW 导致的写延迟, 把其作为单比特旁路实现攻击.  本文提出内存去重可以允许攻击者
读取系统里 的任何数据. 攻击者控制数据的对齐逐字节窃取敏感信息. 论文构造了
一个针对微软Edge 浏览器的端到端的基于JavaScript的攻击, 加上 Rowhammer 手段, 实现对浏览器任意内存的读写.

\cite{miller2013xlh}
利用跨层的 I/O 的提示 (XLH) 来尽快查找和利用去重机会, 减少去重开销.
论文分析认为, 内存去重只对比较静态界面有效, 现有扫描器发现去重机会太慢
(例如5min), 不能利用所有的去重机会. XLH 的快速发现能够去重短生命期页面
并延长长生命期页面被分享时间.

\cite{xiao2013security}
利用内存访问时间差, 构造两种新的攻击, 构造隐蔽通道, 检测虚拟化.
另一方面, 可以使用内存去重来保护内核的完整性.

\cite{chen2014cmd} 基于页面访问特点分类的内存去重, 利用特殊硬件记录
对页面的访问模式, 并进行分类, 去重只在属于相同的类的页面间进行.

\cite{gruss2015practical}第一个利用内存去重的针对JavaScript 沙盒的
内存信息泄露攻击. 受害者只需打开包含攻击者JavaScript代码的网页即可,
攻击者可以得知其正在运行的应用和一些用户操作.

\cite{miller2012ksm++}KSM 对于较为静态的匿名页去重效果良好, 但是对于短生命期
页面难以去重, KSM++ 在宿主机上生成 I/O 提示. 加速扫描.

\cite{kim2011group}现有的内存去重手段,
缺少对隔离的支持, 这对云服务的质量和可信度是重要的. 本文提出方法对
处于同一物理机上的多个虚拟机分组.

\cite{kim2014selective}移动平台上的内存去重, 只扫描被缓存的应用, 可以减少
能耗, 并且只扫描特定虚拟地址的页面, 因为特定虚拟地址重复率大.

\cite{huang2014vmcsnap}虚拟机快照, virutal cluster 上重复页面, 在创建
快照时, 考虑跨虚拟机的页面分享.

\cite{suzaki2012effects}虚拟机的一些安全措施可能对内存去重有影响.
ASLR: Address Space Layout Randomization, 把非活跃内存内存清零等(Memory
Sanitization). 论文分析了Linux 的一些特性对 KSM 的影响. 结果显示,
ASLR 使 4台虚拟机系统的内存消耗增加 18\%, Memory Sanitization 和
page cache flushing 减少内存消耗.

\cite{suzaki2010moving}现有OS包含很多逻辑共享的技巧, 比如共享库,
软连接. 但他们会导致安全和管理上的问题. 比如search path替换攻击..
GOT 覆盖攻击, 依赖地狱.  本文提出 自包含的二进制, 消除这些问题.
自包含导致的存储和内存开销, 由内存和数据去重来缓解.

\cite{ahn2014optimizing}手机上对 KSM 的优化. 如果页面在上几次扫描中
都没有被合并, 那么下一次被合并的概率页很小. 依次优化, 减少 KSM
能耗减少 67.6\%.

\cite{sha2013smartksm}为了提高扫描效率, 将页面分为多个集合, 优先扫描
重复可能性高的集合, 要求(1) 相等内容页面分到同一集合 (2)集合内页面重复
概率分布应该 regular(?).  发现两种有效的分割方式, 根据页面类型(虚拟机中
页面可能是Page Cache, 匿名页, 等), 和根据进程(虚拟机中的进程).

\cite{waldspurger2002memory} VMware’s ESX Server, 最早使用基于内容的页面分享(CBPS)系统.

\cite{arcangeli2009ksm}Linux 主线上的 KSM.

\cite{jia2015coordinate} Memory Parition 指根据页面的颜色给每个虚拟机指定
一个唯一的颜色 (考虑 DRAM 的物理特性) 减少虚拟机之前内存相互干扰.
提出方法协调内存 Partition 与内存去重. 在 内存 Partition 下, 相同内存 bank
的页面之间重复的概率更高.

% miller
\cite{kern2013generalizing}之前的工作大多集中于虚拟机, 本文考虑
 在 Linux 原生应用, 沙盒中的内存去重. 将内存去重相关工作分为两类.

\cite{groninger2013statistical}


\cite{jia2017loc}





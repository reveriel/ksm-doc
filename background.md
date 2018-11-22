# Background

内存去重是指⾃动将内存中重复的数据去重,

最常使⽤的⽅法被称为基于内容的页⾯共享
(Content Based Page Sharing, CBPS), 扫描内存页⾯, 将内容相同的页⾯合并, 共享同⼀物理页,
达到节省内存的⽬的. 在虚拟机管理器上, 因为多个虚拟机有很多重复的数据,
内存去重能达到很好效果, 据 \cite{gupta2008}, 在运⾏相同虚拟机负载时,
节省内存量最⾼可达 90%. 节省的内存可以允许 hypervisor 启动更多的虚拟机, 提升系统吞吐量,
节省硬件成本.

移动设备上, 系统的负载不再是虚拟机, ⽽是各种不同的应⽤. 相⽐虚拟机场景下,
内存的重复会少⼀些. 例如在虚拟机管理器(VMM)上, 可能多个虚拟机读取同⼀个的⽂件, 每个
虚拟机的操作系统都会分配⾃⼰的页缓存(page cache), VMM 可以利⽤ 合并这些页缓存,
也有的⼯作 () 提出利⽤ IO hint 来帮助去重. 在移动设备上只有⼀个操作
系统, 读取同⼀⽂件只会分配⼀份 page cache.\cite{}. 所以针对移动设备需要有新的⽅法.


# KSM

KSM, corresponding file `mm/ksm.c`, merges pages with same
contents. KSM is enabled by setting `CONFIG_KSM=y`. It can saves a lot
of memory in Virutal Machine Hypervisors.

You can mark a pieces of memory as "Mergeable" using syscall
`madvice`, then there is a kthread `[ksmd]` that scan all anonymous
pages in the Mergeable memory area. When found two pages equal, `ksmd`
sets two pages sharing one physical page by using COW(Copy on Write)
mechanism.

The main data struct is two red-black tree used to find equal pages.
Just like we when we want to find repeating numbers in a large array,
sort it or insert to a hashtable are the two most obvious way.

VMware uses the hashtable method in its Virtual Machine products, and
has a patent claim its intellectual property. So Linux community pick
the other way — sort the array.

NOTE: Sort a constantly changing array

The problem is that pages are constantly changing. We need to sort a
changing array.

Those numbers(or pages) that won’t settle, changing very fast, are not
good candidates for sharing. Sharing them would soon get a COW break.
Gone are the sharing and the wasted CPU cycles.

So KSM uses two red-black trees, the `unstable' tree, and the `stable'
tree. Those who haven’t changed for a while, are considered good
candidate, are put into the unstable tree. Note this is a red-black
tree. The changing of pages will gradually turn it out of order. So the
unstable tree is emptied every some time.

TODO: find out how does KSM empty the unstable tree.

The stable tree lives those who are merged to a read only page. They
won’t change, so the stable tree is always in order.

See `mm/ksm.c:cmp_and_merge_page()`

```
When `ksmd` inspect an anonymous page,
First search it in the stable tree.
if found:
  merge the page
else, no found:
  has the page changed since 'ksmd' last saw him?
  if yes, changed:
     out, I don't think our sharing service is suitable for you
  eles, no changed:
     put you in the unstable tree.
     maybe you can find someone equal to you
     if found an equal page here
        you both move to the stable tree.
```

Basically, that’s all.
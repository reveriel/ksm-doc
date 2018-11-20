### KSM

KSM(Kernel Samepage Merging). Try to improve it. Based on
[PKSM](code.google.com/archive/p/pksm). Kernel v3.18-rc7

## Possible plans

* delay
* hash adjustable.
* test uksm
* hash table instead of rbtree
* same virtual address
* page cache

## Background

### BG: KSM

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

### BG, PKSM

PKSM (file `mm/pksm.c`) made some changes to the
original KSM.

It has three queues as worklists.
- new anon page list, or new list.
  every new anon page is added to this list.
- rescan anon page list, or rescan list.  -
  pages that failed to merge, or removed from unstable tree
- delete anon page list, or del list.

Every anonymous pages born into the world(system) are put in the new
list. Those who failed during merge were added to the rescan list.
ksmd(or pksmd) also scans the unstable tree and picks up those who’s
content has changed, adds them to the rescan list.

The candidate to be to put to the test of `cmp_and_merge_page()` are
half from new list, half from rescan list.

The del list is just for the convenience of release the data structure
for each anonymous page. Every processes in the system may allocate new
anonymous pages and release them. When releasing, the corresponding data
structure is simply marked and leave the actual deallocation to ksmd.

Pksm also has a special zero page, every anonymous page is first tried
to merge with this. Empirically zero pages are more than others.

And, when deciding if two pages are equal, the partial hash values are
compared first. A byte-by-byte comparison is done only when partial hash
values are the same.

I think that’s all of PKSM. Quite short, isn’t it.

## Possible Plans

- delay
- hash adjustable.
- test uksm
- hash table instead of rbtree
- same virtual address
- page cache

### Plan: Delay

"Every new page is added to the new list." Is there any problem?

Also, every page is first search in the stable tree. That sounds bad.
A new-born page may change very soon. Normally We allocate memory
not for fun, but to put data in it. New page may not be a promising
candidate for sharing.

Possible solution: *Delay*

Pages should stay here for a while. If a page arrived at new list, we
should give it a probation period. Then decided if it is suitable for
merge based on its behavior.

But! This also slows the merging, make it less responsive.

Here is the trade-off. We slows down the merging:

* Pro:: less COW break, less CPU usage.
* Con:: less responsive, can not merge short lived pages, less memory saving.

NOTE: Maybe we could measure it and find the optimal solution? See


#### Design

```
                   "the new list"
 new page add to ---> [ [cnt] [cnt] [cnt]  ... [cnt] ]
                          1     0     5    ...   4
       ksmd scan it, inc the `cnt`
       if the `cnt` is greater than N, move to candidate list.
                         |   "the candidae list"
                         +---> [ []  [] ... []]
```
Scan the new list: do

1. Inc counter, if counter > N, move to candidate.
2. If marked DEL, move to del list.

While a pages stays in the new list, it may be freed, changed. If freed,
it's marked DEL. If it has changed?

If it has changed, see PG_referenced, PG_active, PG_lru.
如果页面发生了变化, 看 PG_reference 和 PG_active. 还有 PTE 的 Accessed, Dirty bits.
什么关系?

页面可能有四种情况.
* active, referenced
* active, unreferenced
* inactive, referenced
* inactive, unreferenced

检查 PG_dirty 和 pte_dirty, 如果其中有一个set, cnt 清零.

但是这只体现了 页面被 "读或者写" 的情况, 真正需要知道的是页面内容是否改变.
可能页面被改变了.

在 `mark_page_accesed()` 里面提醒一下 ksm ?


另外如果选择不常使用的页面.
不常使用的页面, 更容易成为 swap 换出的对象.
如果把它合并了, 对 swap 有什么影响?

合并页面, 将第一个非 ksm 页面设为写保护时, 会调用 `mark_page_accessed`.
相当于访问了一次该页面.

QUESTION: KsmPage 会被 swap out 吗?

内存去重显然是应该优先于 swap 的, swap 涉及I/O. 而根据 论文 ..,
内存去重也优于内存压缩.

Two parameters here: the scan freqency, and the N. These can be seen as one
parameter --- How long does a page stay in the new list.

Time = ListLength / ScanFreqency * N

pages_to_scan 的调整:
根据现有内存



##### Accounting

Slow the merge speed.

* Pro:: less COW break, less CPU usage.
* Con:: less responsive, can not merge short lived pages, less memory saving.

COW break 可以量化, 合并页面也可以量化, 缺少目标函数, 怎么将它们合并到一个
维度上? 时间?

COW break 时间惩罚还行, merge 页面的时间奖励怎么算?







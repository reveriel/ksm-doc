
### BG, PKSM

PKSM (file `mm/pksm.c`) made some changes to the
original KSM.

It has three queues as worklists.
- new anon page list, or new list.
  every new anon page is added to this list.
- rescan anon page list, or rescan list.  -
  pages that failed to merge, or removed from unstable tree
- delete anon page list, or del list.

Every anonymous pages born into the system are put in the new
list. Those who failed during merge were added to the rescan list.
ksmd(or pksmd) also scans the unstable tree and picks pages whose
content has changed, adds them to the rescan list.

The candidate pages to be to put to the test of `cmp_and_merge_page()` are
half from new list, half from rescan list.

The del list is just for convenience of the release of data structure
for each anonymous page. Every processes in the system may allocate new
anonymous pages and release them. When releasing, the corresponding data
structure is simply marked and leave the actual deallocation to ksmd.

Pksm also has a special zero page, every anonymous page is first tried
to merge with this. Empirically zero pages are more than others.

And, when deciding if two pages are equal, the partial hash values are
compared first. A byte-by-byte comparison is done only when partial hash
values are the same.

I think that’s all of PKSM. Quite short, isn’t it.

Wait!

每个新分配的物理页.
```
page <-> rmap_item
```


### Delay

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
       if the `cnt` is greater than N, try to merge
```
Scan the new list: do

1. Inc counter, if counter > N, try to merge
2. If marked DEL, move to del list.
3. While a pages stays in the new list, it may be freed, changed.
   If freed, it's marked DEL.

If it has changed, see PG_referenced, PG_active, PG_lru.
如果页面发生了变化, 看 PG_reference 和 PG_active. 还有 PTE 的 Accessed, Dirty bits.
什么关系?

~~检查 PG_dirty 和 pte_dirty, 如果其中有一个set, cnt 清零. XX~~

这个是物理页, 有多个 pte 对应的, 可以看 PageDirty(), 但是不一定准确, 因为 swapd 会
把这个 bit 定时清掉. 然后会变成  PG_referenced 和 PG_active.



<!--
页面可能有四种情况. 展示
* active, referenced
* active, unreferenced
* inactive, referenced
* inactive, unreferenced
但是这只体现了 页面被 "读或者写" 的情况, 真正需要知道的是页面内容是否改变.
可能页面被改变了.

另外如果选择不常使用的页面.
不常使用的页面, 更容易成为 swap 换出的对象.
如果把它合并了, 对 swap 有什么影响?

合并页面, 将第一个非 ksm 页面设为写保护时, 会调用 `mark_page_accessed`.
相当于访问了一次该页面.
-->


<!--
在 `mark_page_accesed()` 里面提醒一下 ksm ?
-->

QUESTION: KsmPage 会被 swap out 吗?

内存去重显然是应该优先于 swap 的, swap 涉及I/O. 而根据 论文 ..,
内存去重也优于内存压缩.

#### 算法参数

页面在被去重之前的等待时间 Time:

Time = ListLength / ScanSpeed * N

ScanSpeed = pages_to_scan / sleep_milliseconds

其中 ListLength 是 new list 的长度. ScanSpeed 是 ksmd 扫描速度m,
等于 每次被唤醒时 扫描页面个数 除以 相邻两次唤醒的间隔时间.
N 是页面在 new list 被扫描几次后才去重.

pages_to_scan, sleep_milliseconds, N 是需要确定的参数.
可以看做是一个参数, (N * sleep_milliseconds / pages_to_scan)
决定 Time 的大小.

ListLength 是当时 new list 的长度. 在程序启动时可能会突然增加.
如果 ScanSpeed 与 ListLength 正相关, 可能导致与应用程序竞争 CPU, 
而且程序启动时刚分配的页面可能立即需要使用. 所有 ScanSpeed 应该与
ListLength 无关或者负相关.

暂时随便指定. N = 3,



#### Accounting

Slow the merge speed.

* Pros: less COW break, less CPU usage.
* Cons: less responsive, can not merge short lived pages, less memory saving.

COW break 可以量化, 合并页面也可以量化, 缺少目标函数, 怎么将它们合并到一个
维度上? 时间?

COW break 时间惩罚还行, merge 页面的时间奖励怎么算?









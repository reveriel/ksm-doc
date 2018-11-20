### Page table

[Page Table Management](https://www.kernel.org/doc/gorman/html/understand/understand006.html)

Each process has a pointer `mm_struct->pgd` points to its own *Page Global
Directory(PGD)* which is a physical page frame. The frame contains an array
of type `pgd_t` which is an architecture specific type defined in `<asm/page.h>`

PGD -> *Page Middle Directory(PMD)* -> *Page Table Entries(PTE)*

pte points to page frames.

When swap out, the swap entry is stored in the PTE and used by
`mm/memory.c:do_swap_page()`

There are some bits about each page. 

see `arch/xx/include/asm/pgtable.h`

protection:

The read permissions for an entry are tested with `pte_read()`, set with `pte_mkread()` and
cleared with `pte_rdprotect()`;
The write permissions are tested with `pte_write()`, set with `pte_mkwrite()` and cleared with
`pte_wrprotect(`);
The execute permissions are tested with `pte_exec()`, set with `pte_mkexec()` and cleared with
`pte_exprotect()`. It is worth noting that with the x86 architecture, there is no means of
setting execute permissions on pages so these three macros act the same way as the read
macros;
The permissions can be modified to a new value with `pte_modify()` but its use is almost
non-existent. It is only used in the function `change_pte_range()` in `mm/mprotect.c`.

state:

The fourth set of macros examine and set the state of an entry. There are only two bits
that are important in Linux, the dirty bit and the accessed bit. To check these bits, the
macros `pte_dirty()` and `pte_young()` macros are used. To set the bits, the macros
`pte_mkdirty()` and `pte_mkyoung()` are used. To clear them, the macros `pte_mkclean()` and
`pte_old()` are available.


The macro `mk_pte()` takes a `struct page` and protection bits and combines them together to
form the `pte_t` that needs to be inserted into the page table. A similar macro
`mk_pte_phys()` exists which takes a physical page address as a parameter.


The macro `pte_page()` returns the `struct page` which corresponds to the PTE entry.
`pmd_page()` returns the `struct page` containing the set of PTEs.


Code in x86:

``` c
#define pte_page(pte)	pfn_to_page(pte_pfn(pte))
```

PTE 转换成 PFN, PFN 从 PageInfo 数组里面获取 PageInfo(即 `strcut page`). 
Linux 里面似乎将 PageInfo 数组分成了多个section, 可能是为了支持 sparse memory.


``` c
static inline unsigned long pte_pfn(pte_t pte)
{
	return (pte_val(pte) & PTE_PFN_MASK) >> PAGE_SHIFT;
}
```

seciton ?

`struct mem_section`, is, logically, a pointer to an array of struct pages.

``` c
#define pfn_to_page __pfn_to_page
#define __pfn_to_page(pfn)                              \
({      unsigned long __pfn = (pfn);                    \
	struct mem_section *__sec = __pfn_to_section(__pfn);    \
	__section_mem_map_addr(__sec) + __pfn;          \
})

static inline struct mem_section *__pfn_to_section(unsigned long pfn)
{
	return __nr_to_section(pfn_to_section_nr(pfn));
}

#define pfn_to_section_nr(pfn) ((pfn) >> PFN_SECTION_SHIFT)
#define section_nr_to_pfn(sec) ((sec) << PFN_SECTION_SHIFT)

static inline struct page *__section_mem_map_addr(struct mem_section *section)
{
	unsigned long map = section->section_mem_map;
	map &= SECTION_MAP_MASK;
	return (struct page *)map;
}
```

QUESTION: `pte_dirty()` and `PageDirty()`, diff?

PTE 里面也有 dirty bit, PageInfo 里面也有 `PG_dirty`, 两者的关系?

不考虑这两个 bit, 单纯从计算机的状态来讲, 可能两者不一致吗?
如果 PTE 表示映射到的物理页的 dirty, 逻辑页的 dirty?

如果是 x86 的话, pte 的 dirty bit 是 CPU/MMU 维护的, PageInfo 是内核代码维护的.
参考 [i386 的手册](https://pdos.csail.mit.edu/6.828/2018/readings/i386/s05_02.htm),

> 这些位提供有关页面表的两个级别中的页面使用情况的数据。
> 除了 PTE 中的脏位之外，这些位由硬件设置; 但是，处理器不会清除任何这些位。

> 在对页面进行读或写操作之前，处理器将两个级别的页表中的相应 access 位设置为1。

> 在写入该页表条目所覆盖的地址之前，
> 处理器将第二级页表(即PTE, 386 有两级页表, 一个里面是 PDE, 一个里面是 PTE)中的脏位设置为1。 
> PDE 中的脏位未定义。

> 支持分页虚拟内存的操作系统可以使用这些位来确定当内存需求
> 超过可用物理内存时要从物理内存中消除的页面。
> 操作系统负责测试和清除这些位。

> 也就是说内核要保证 PageInfo 的信息是和 PTE 的信息同步的.

pte 里面的 access 又叫做 young.

``` c
static inline int pte_young(pte_t pte)
{
        return pte_flags(pte) & _PAGE_ACCESSED;
}
```



### page replacement

pte 有 dirty 和 access(young) bits.
Page 有 dirty bit, 还有 referenced/active bits.

### page frame reclaiming algorithm(PFRA)

PFRA 把页面分成:

* **unreclaimable**, 包括 伙伴系统里的 Free pages. Reserved Pages(PG_reserved set),
  kernel 动态分配的页面, 进程在内核模式的栈页面, 临时 Locked 页面(PG_locked),
  在被锁内存区域的页面 (vma 的 VM_LOCKED set).
* **swappable**,包括 用户空间的匿名页, tmpfs 映射的页面.
* **syncable**, 包括用户空间的 mapped pages, pages cache, block device buffer pages,,
  pages of some disk caches.
* **discardable**, Unsed pages included in memory caches(e.g., slab allocator caches) ,
  Unused pages of dentry cache.

syncable 页面回收时需要检查 dirty bit.

回收优先考虑

reverse mapping.

每个内存区域描述符标出一个指向内存描述符的指针, 内存毛师傅包含指向 PGD 的指针
所以

`_mapcount` 保存指向这个页面的 PTE 个数, 从 -1 开始计数.

`mapping` 如果是 NULL, 页面术语 swap cache. 如果非NULL且最低位为1, 则是匿名页,
`mapping` 指向 `anon_vma`. 

引用了同一个 page frame 的 anonymous memory regions (`anon_vma`)连成一环形链表.
pageInfo 里面保存一个链表, 指向所有 map 到这个 page frame 的 pte, 这样的做法
效率低.改成 pageInfo 指向(保存) 一个链表, 链表里是所有 map 到这个 page frame
的 vma. 

(在 umap 时会检测 accessed bit, 如果正在使用, 则clear bit, 返回失败)

LRU lists.

PG_referenced, 使page 在 inactive list 和 active list 之间状态转化需要的
两次连续触发.

向 active list 的触发函数为 `mark_page_accesed()`. 在页面被用户进程, 文件系统层,
或设备驱动访问时调用. 调用时, 如果 PG_referenced bit 为 0, 置 1. 如果为1, 把页面
移动到 active list, 置 referenced bit 为 0.

另一个方向, 包含两个函数 `page_referenced()`, `refill_inactive_zone()`.
PFRA 扫描时对所有页面调用 `page_referenced()`, 
如果 PG_referecned is set, clears it, 然后使用
反向映射清除 所有指向这个 page frame 的 PTE 的 Accessed bit.
把页面从 active 移到 inactive 由 `refill_inactive_zone()`完成.

`refill_inactive_zone()` 由 `shrink_zone()`调用, `shrink_zone()` ...,
有两个参数, zone, 和 scan_control.

把页面从 active 移到 inactive 意味着这个页面之后可能被回收掉, 所以需要小心.










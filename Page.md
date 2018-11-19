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
如果 PTE 表示映射到的物理页的 dirty, 逻辑页的 dirty? 都是物理页的, 
逻辑页面可能没有 PTE.

如果是 x86 的话, pte 的 dirty bit 是 CPU/MMU 维护的, PageInfo 是内核代码维护的.
参考 [i386 的手册](https://pdos.csail.mit.edu/6.828/2018/readings/i386/s05_02.htm),

> 这些位提供有关页面表的两个级别中的页面使用情况的数据。
> 除了 PTE 中的脏位之外，这些位由硬件设置; 但是，处理器不会清除任何这些位。

> 在对页面进行读或写操作之前，处理器将两个级别的页表中的相应 access 位设置为1。

> 在写入该页表条目所覆盖的地址之前，
> 处理器将第二级页表(即PTE, 386 有两级页表, 一个里面是 PDE, 一个里面是 PTE)中的脏位设置为1。 
> PDE 中的脏位未定义。

> 支持分页虚拟内存的操作系统可以使用这些位来确定当内存需求超过可用物理内存时要从物理内存中消除的页面。
> 操作系统负责测试和清除这些位。

也就是说内核要保证 PageInfo 的信息是和 PTE 的信息同步的.




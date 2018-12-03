# alloc and free pages

## alloc and page fault

where does those pages come form ?

``` c
int pksm_add_new_anon_page(struct page *page, struct rmap_item,
        struct anon_vma* );
```

this is called in only one place `mm/memory.c`

``` c
static int do_anoymous_page(struct mm_struct *mm, struct vm_area_struct *vma,
                unsigned long address, pte_t *page_table, pmd_t *pmd,
                unsigned int flags)
{

}
```

`do_anoymous_page()` is called only in `handle_pte_fault()`.
when the pte entry is not present, pte.pte == 0,

`handle_pte_fault()` is called only in `__handle_mm_fault()`

```
handle_mm_fault()
-> __handle_mm_fault()
  --> handle_pte_fault()
    --> do_anoymous_page()
      --> pksm_add_new_anon_page()
```

似乎在 `mm/gup.c` 里面有调用 `handle_mm_fault()`,
 `mm/gup.c` was move out from `mm/memory.c` file,
and is about `get_user_pages()`.

还有 `arch/x86/mm/fault.c`  调用 `handle_mm_fault()`

`arch/x86/mm/fault.c`
``` c
/* this routine handles page faults, It determines the address,
 * and the problem, and then passes it off to one th of appropriate
 * routines.
 */
static noinline void
__do_page_fault(struct pt_regs *regs, unsigned long error_code,
                unsigned long address)
{
//  unlikey 的一些情况处理完后:
    fault = handle_mm_fault(mm, vma, address, flags);
}
```

``` c
static int __handle_mm_fault(mm, vma, address, flags)
{
// 分配各级页表. 现在有一个 pte了. 接下来应该要分配物理页面
// 以及建立映射了吧
    pte = pte_offset_map(pmd, address);
    return handle_pte_fault(mm, vma, address, pte, pmd, flags);
}

// 分情况 好几种 do_xxx
static int handle_pte_fault(mm, vma, address, pte, pmd, flags)
{
    entry = ACCESS_ONCE(*pte);
    if (!pte_present(entry)) {// page 不在内存里
        if (pte_none(entry)) { // pte = 0,
            if (vma->vm_ops) {
                if (likely(vma->vm_ops_fault)) // 基于文件的映射. vma 里面有相应的处理
                    return do_linear_fault(mm, vma, address, pte, pmd, flags, entry);
            }
            // 分配匿名页
            return do_anoymous_page(mm, vma, address, pte, pmd, flags);
        }
        // 非线性文件映射, 而且被换出了
        if (pte_file(entry))
            return do_nonlinear_fault(mm, vma, address, pte, pmd, flags, entry);
        // page 不在内存, 页表项里有信息, 说明被换出了, swap in
        return do_swap_page(mm, vma, address, pte, pmd, flags, entry);
    }
    if (pte_numa(entry))
        return do_numa_page(mm, vma, address, entry, pte, pmd);
    // lock pte
    // page 在内存里面, 写page 发生的异常,
    if (flags & FAULT_FLAG_WRITE) {
        if (!pte_write(entry)) // pte : not writable, 发生 COW
            return do_wp_page(mm, vma, address, pte, pmd, ptl, entry);
        // 这个? 可以写却发生异常, mark dirty
        entry = pte_mkdirty(entry);
    }
    entry = pte_mkyoung(entry); // accessed
    if (ptep_set_access_flags(vma, address, pte, entry, flags & FAULT_FLAG_WRITE)) {
        update_mmu_cache(vma, address, pte);
    } else {
        if (flags & FAULT_FLAG_WRITE)
            flush_tlb_fix_spurious_fault(vma, address);
    }
    // unlock
    return 0;
}
```


``` c
// COW 好像有两种, 一种是文件映射的, 在 do_linear_fault 和 do_nonlieanr fault.
// 文件的最后都调用的是 __do_fault() --> vma->vm_ops->fault(),
static int do_nonlinear_fault(mm, vma, address, page_table, pmd, flags, orig_pte) {
    pte_unmap_same()
    pgoff = pte_to_pgoff(orig_pte);
    if (!flag & FAULT_FLAG_WRITE)
        return do_read_fault(mm, vma, address, pmd, pgoff, flags, orig_pte);
    if (!(vma->vm_flags & VM_SHARED))
        return do_cow_fault(mm, vma, address, pmd, pgoff, flags, orig_pte);
    return do_shared_fault(mm, vma, address, pmd, pgoff, flags, orig_pte);
}
static int do_linear_fault(mm, vma, address, page_table, pmd, flags, orig_pte) {
    pgoff = (((address & PAGE_MASK) - vma->vm_start) >> PAGE_SHIFT) + vma->vm_pgoff;
    pte_unmap(page_table);
    if (!flag & FAULT_FLAG_WRITE)
        return do_read_fault(mm, vma, address, pmd, pgoff, flags, orig_pte);
    if (!(vma->vm_flags & VM_SHARED)) // 并不是共享的, 你却在写它.
        return do_cow_fault(mm, vma, address, pmd, pgoff, flags, orig_pte);
    return do_shared_fault(mm, vma, address, pmd, pgoff, flags, orig_pte);
}

static int do_cow_fault(mm, vma, address, pmd, pgoff, flags, orig_pte) {
    anon_vma_prepare(vma); // rmap
    new_page_alloc_pages_vma(GFP_HIGHUSER_MOVABLE, vma, address);
    ret = __do_fault(vma, address, pgoff, flags, &fault_page);
    copy_user_highpage(new_page, fault_page, address, vma);
    // 这里分配了一个匿名页, 复制过来.
    do_set_pte(vma, address, new_page, pte, (writable)true, (anon)true);
}
// 估计 __do_fault 那里读文件时, page cache 有特殊的处理吧.
```

``` c
static int do_anonymous_page(mm, vma, address, page_table, pmd, flags) {
    pte_unmap(page_table)
    if (!(flags & FAULT_FLAG_WRITE)) {
        entry = pte_mkspecial(pfn_pte(my_zero_pfn(address), vma->vm_page_prot));
        page_table = pte_offset_map_lock(mm, pmd, address, &ptl);
        goto setpte;
    }
    anon_vma_prepare(vma); // rmap
    page = alloc_zeroed_user_highpage_movable(vma, address);
    entry = mkpte(page, vma->vm_page_prot);
    if (vma->vm_flags & WM_WRITE)
        entry = pte_mkwrite(pte_mkdirty(entry));

    rmap = pksm_alloc_rmap_item();

    page_table = pte_offset_map_lock(mm, pmd, address, &ptl);
    page_add_new_anon_rmap(page, vma, address);
setpte:
    set_pte_at(mm, address, page_table, entry);

    if (rmap)
        pksm_add_new_anon_page(page, rmap, vma->anon_vma);
}
```


``` c
// handles present pages, when useres try to write to a shared page.
// It is done by copy the page to a new address and dec the shared-page counter
// for the old page
static int do_wp_page(mm, vma, address, page_table, pmd, ptl, orig_pte) {
    old_page = vm_normal_page(vma, address, orig_pte);
    // take out anonymous
    if (PageAnon(old_page) && !PageKsm(old_page)) {

        // we can write to an anon page without COW if there are no other
        // references to it. as a side-effect, free up its swap:
        // because the old content on disk will never be read,
        // and seeking back there to write new content later would only
        // waste time away from clustering.
        // see swap.md
        if (reuse_swap_page(old_page)) // we {
            page_move_anon_rmap(old_page, vma, address);
            goto reuse;
        }

    } else if (unlikely((vma->vm_flags & (VM_WRITE|VM_SHARED)) == (VM_WRITE|VM_SHARED)))
    {

    }
    dirty_page = old_page;
    get_page(dirty_page);
reuse:
    // resue
gotten:
    // copy
    if (is_zero_pfn(pte_pfn(orig_pte))) {
        new_page = alloc_zeroed_user_highpage_movable(vma, address);
    } else {
        new_page = alloc_page_vma(GFP_HIGHUSER_MOVABLE, vma, address);
        cow_user_page(new_page, old_page, address, vma);
    }
    // recheck the pte - we dropped the lock
    if (likely(pte_same(*page_table, orig_pte))) {
        if ()

        // why do it HERE! TODO
        if (old_page) {
            pksm_unmap_sharing_pgae(old_page, mm, address);
            page_remove_rmap(old_page);
        }
        // free the old page.
    } else
}

static inline void cow_user_page(dst, src, va, vma) {
    if (unlikely(!src)) {
     ...
    } else
        copy_user_highpage(dst, src, va, vma);
}
```

暂时认为, 每个新分配的匿名页都会加入 new list.


``` c
#ifdef CONFIG_NUMA
alloc_page(gfp_mask, order) {
    return alloc_pages_current(gfp_mask, order);
}
alloc_pages_vma();
#else
#define alloc_pages(gfp_mask, order) \
            alloc_pages_node(numa_node_id(), gfp_mask, order)
#define alloc_page_vma(gfp_mask, order, vma, addr, node) \
            alloc_pages(gfp_mask, order)
#endif

#define alloc_page(gfp_mask)  alloc_pages(gfp_mask, 0)

// 这个干什么的?
void alloc_pages_exact(size_t size, gfp_t gfp_mask)
{
    addr = __get_free_pages(gfp_mask, order);
    return make_alloc_exact(addr, order, size);
}

unsigned long __get_free_pages(gfp_t gfp_mask, unsigned int order)
{
    page = alloc_pages(gfp_mask, order);
    return (unsigned long) page_address(page);
}

// include/linux/gfp.h  get free page
static inline struct page *
alloc_pages(gfp_t gfp_mask, unsigned int order)
{
    return alloc_pages_current(gfp_mask, order);
}

// "mm/mempolicy.c" simple NUMA memory policy for the linux kernel.
// allows the user to give hits in which node(s) memory should be allocated
// support four policies per vma and per process.
//  interleave, bind, preferred, default
//  alloc_pages_current  - Allocate pages
// @gfp:
//     %GFP_USER  user allocation,
//     %GPF_KERNEL kernel allocation
//     %GPF_HIGHMEM highmem allocation
//     %GPF_FS      don't call back into a file system
//     %GPF_ATOMIC  don't sleep
//  @order: Power of two of allocation size in pages. 0 is a single page.
//  Allocate a page from the kernel page pool.
struct page *alloc_pages_current(gfp_t gfp, unsigned order)
{
    if (pol->mode == MPOL_INTERLEAVE)
        page = alloc_page_interleave(gfp, order, interleave_nodes(pol));
    else
        page = __alloc_pages_nodemask(gfp, order,
                    policy_zonelist(gfp, pol, numa_node_id()),
                    policy_nodemask(gfp, pol));
    return page
}

static struct page *alloc_page_interleave(gfp_t gfp, unsigned order,
                                    unsigned nid)
{
    zl = node_zonelist(nid, gfp);
    page = __alloc_pages(gfp, order, zl);
}

// "gfp.h"
struct inline struct page *
__alloc_pages(gfp_t gfp_mask, unsigned int order, struct zonelist *zonelist)
{
    return __alloc_pages_nodemask(gfp_mask, order, zonlist, NULL);
}

// "mm/mempolicy.c"
// 两条路都是调用这个.
// This is the 'heart' of the zoned buddy allocator
struct page *
__alloc_pages_nodemask(gfp_t gfp_mask, unsigned int order,
                        struct zonelist *zonelist, nodemask_t *nodemask)
{
    page = get_page_from_freelist(gfp_mask|__GFP_HARDWALL, nodemask, order,
                            zonelist, high_zoneidx,alloc_flags,
                            preferred_zone, classzone_idx, migratetype);
    if (unlikely(!page)) {
        page = __alloc_pages_slowpatch( ... );
    }
}
```

## 释放 free

`pksm_del_anon_page()` called only in `mm/page_alloc.c`, `mm/page_alloc.c`
manges the free list, the system allocates free pages here.

`mm/page_alloc.c`:

``` c
// 这个只是释放 0-order pages 的?
void free_hot_cold_page(struct page *page, bool cold)
{
    if (PagePKSM(page))
        pksm_del_anon_page(page);
}
```

``` c
// free a list of 0-order pages
free_hot_cold_page_list(list, cold)
--> free_hot_cold_page(page, cold)

void __free_pages(struct page *page, unsigned int order)
{
    if (put_page_testzero(page)) {
        if (order == 0)
            free_hot_cold_page(page, false);
        else
            __free_pages_ok(page, order);
    }
}

static void __free_pages_ok(struct page *page, unsigned int order)
{
    // ...
    free_one_page(page_zone(page), page, pfn, order, migratetype);
}

static void free_one_page(zone, page, pfn, order, migratetype)
{
    // ...
   __free_one_page(page, pfn, order, migratetype);
}

// free page to buddy system.
static inline void __free_one_page(page, pfn, order, migratetype)
{
    // 到这里就差不多了
}
```

`mm/page_alloc.c`
暴露三个函数 `free_hot_cold_page()` `free_hot_cold_page_list()` `__free_pages()`,
头文件为 `gfp.h` :

``` c
extern void __free_pages(page, order);
extern void free_pages(addr, order);
extern void free_hot_cold_page(page, cold);
extern void free_hot_cold_page_list(list, cold);
#define __free_page(page) __free_pages((page), 0)
#define free_page(addr) free_pages((addr), 0)
```
还有 `free_kmem_pages(page, order)`, 下面也是调用的 `__free_pages()`

总之, 单个页面释放则调用 `free_hot_cold_page()`, 连续页面释放则调用 `free_one_page()`.
单个页面释放时, 需要做一些额外的检测, 因为每个cpu有几个 per cpu page list. 要看能不能
回收到这些list 里面, 如果不行, 再调用 `free_one_page()`.


## 在往上呢

alloc_page 和 free_page 在到处都有使用了.

## get and put

还有一对 get 和 put.




``` c
static inline void get_page(struct page *page)
{
    if (unlikely(PageTail(page)))
        if (likely(__get_page_tail(page)))
            return;
    // getting a normal page or the head of a compound page
    // requires to already have an elevated page->_count
    VM_BUG_ON_PAGE(atomic_read(&page->_count) <= 0, page);
    // 引用计数.
    atomic_inc(&page->_count);
}
```

``` c
struct page {

}
```






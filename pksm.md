# pksm

## page 合并.

``` c
cmp_and_merge_page(page, rmap_item, init_checksum) {

}
```
`page` and `rmap_item` 有点多余. `page == rmap_item->page`
并且 `page->pksm == page`.

``` c
remove_rmap_item_from_tree(rmap_item, free_anon) {
    if (rmap_item->address & STABLE_FLAG)
        rb_erase(&rmap_item->node, &root_stable_tree);
    else if (rmap_item->address & UNSTABLE_FLAG) {
        rb_erase(&rmap_item->node, &root_unstable_tree);
	if (rmap_item->address & CHECKSUM_LIST_FLAG)
	    list_del_init(&rmap_item->update_list)
    }
    if (free_anon && !hlist_empty(&rmap_item->hlist)) {
    hlist_for (stable_anon, &rmap_item->hlist) {
            put_anon_vma(stable_anon->anon_vma);
	    free_stable_anon(stable_anon)
        }
    }
}
```

``` c
try_to_merge_zero_page(page)
{
    if (PageTransCompound(page) && page_trans_compound_anon_split(page))
        goto out;
}
```

compound page, 这里?

``` c
static int page_trans_compound_anon_split(page)
{
    struct page *transhuge_head = page_trans_compound_anon(page);
}

static struct page *page_trans_compound_anon(page)
    if (PageTransCompound(page))
        struct page *head = compound_head(page);
	if (PageAnon(head))
	    return head;
```

见 `mm/page_alloc.c`

>  higher-order pages are called "compound pages". They are structure thusly:
>    the first PAGE_SIZE page is called the head page
>    the remaining PAGE_SIZE pages are called tail pages
>    All pages have PG_compound set. All tail pages have their ->first_page
>  poting at the head.
>    the first tail page's ->lru.next holds the address of the compound page's
>  put_page() function. Its ->lru.prev holds the order of allocation.
>  This usage means that zero-order pages may not be compound.

`mm.h`
> compound pages have a destructor function.

ref : [An introduction to compound pages](https://lwn.net/Articles/619514/)

A compound page is simply a grouping of two or more physically contiguous pages into a
unit that can, in many ways, be treated as a single, larger page. 
- used to create huge pages, in hugetlbfs, transparent huge pages..
- serve as anonymous memory, or used as buffer in kernel.
- cannot be in page cache.


``` c
pages = alloc_pages(GPF_KERNEL, 2)
```
这个如果给了我 4 个页, 怎么用 一个 struct page 表示?
this will return four physically contiguous pages, but they will not be a compound page. 

alloc a compound page:

得到这个页面, 怎么用? 如果是内核的?

又搞不清 lowmem 之类的了. 

??????










## unstable tree 扫描.

`ksm_do_scan()` 最后会扫描 unstable tree 的节点. 重新计算 checksum, 把checksum
发生变化的页面删除.

``` c
static void pksm_upsate_unstable_page_checksum()
{
    need_scan = pksm_calc_update_pages_num();
    need_scan = min(need_scan, ksm_thread_pages_to_scan);
    list_for_each_entry_safe(rmap_item, n_item, &unstabletree_checksum_list, update_list) {
        page = rmap_item->page.
        if (!get_page_unless_zero(page))
            got_out;
        checksum = calc_checksum(page);
        if (rmap_item->checksum != checksum) {
            rmap_item->checksum = checksum;
            goto re_cmp;
        } else
            goto putpage;
re_cmp:
        remove_rmap_item_from_tree(rmap_item, 0);
        list_add_tail(&rmap_item->list, &new_anon_page_list); // 加入 new list.
putpage:
        put_page(page);
out:
        if (scan++ > need_scan)
            break;
        cond_resched()
    }
}
```

扫描的页数: `need_scan`

``` c
static unsigned int pksm_calc_update_pages_num(void)
{
    unsigned int need_scan = 0;
    if (ksm_pages_unshared < ksm_thread_pages_to_scan)
        need_scan = ksm_pages_unshared;
    else
        need_scan = (ksm_pages_unshared * ksm_thread_sleep_millisec) / (pksm_unshared_page_update_period * 100);
    return need_scan;
}
```

`pksm_unshared_page_update_period = 10`, secconds pksm should update all
unshared_pages by one period.

10秒钟扫描完所有 unstable tree nodes N(数量为 ksm_pages_unshared).
10 * 1000 = N / (need_scan / sleep_ms)

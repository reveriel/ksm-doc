# pksm


Q: cow 发生后是怎么样?


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
split the compound page.. split_huge_page 求 CONFIG_TRANSPARENT_HUGEPAGE.
手机上没有开.

`pksm_rmap_walk(page, pksm_merge_zero_page, zero_page)`

`pskm_rmap_walk(page, int(*rmap_one)(page,vma,addr,arg), arg)`

这里有 rmap walk了, 在 ksm 里面, 没有这样, ksm 里面
将 (vma,page) 和 kpage 合并, (vma,page) 相当于一个映射到 page 的虚拟页面. 
合并时只把这一个 pte 修改, pksm 里面, rmap walk 估计就是要把所有
映射到这个 page 的 pte 修改掉了.

> 感觉我知道哪里有问题了, rmap.c 里面 的 rmap_walk 调用的函数是错的.
> TODO: check

然后 in `pksm_merge_zero_page(page, vma, addr, kpage)`

``` c
if ((err = write_protect_page(vma, page, &orig_pte)) == 0) {
     if (is_page_full_zero(page))
         err = replace_page(vma, page, kpage, orig_pte);
}
```
这里先 write protect page 再检测 is full zero.  也对, 不然可能被改了?
并不会, 在 `try_to_merge_zero_page()` 时就已经 lock page 了.

把这个 pte 设为不可写.

``` c
static int write_protect_page(vma, page, orig_pte) {
if (pte_write(*ptep) || pte_dirty(*ptep))
   // 如果可写, 或者 dirty?
   // 如果 pte dirty, set page dirty
   // 关于 swap cache 不太懂.
   // clear Dirty flag, and clears write flag
   entry = pte_mk_clean(pte_wrprotect(entry));
   set_pte_at_notify(mm, addr, ptep, entry);
}
```

``` c
// replace page in vma by new ksm page..
static int replace_page(vma, page, kpage, orig_pte) {
    ptep = pte_offset_map_lock(mm, pmd, addr, &ptl);
    // 这个是 pmd 所在 page 的 spinlock. 可能是因为要修改
    // 之前在写保护时, page_check_address 也会锁 pte(锁的是pmd 的page)
    if (!pte_same(*ptep, orig_pte)) {
        // 这个判断, 这个 page  的pte 和之前的是否一样
        // write_protect_page 时, orig_pte 设置成了 写保护的flag.
        // 如果这时发现不同了, 说明在 两个函数调用之间发生了什么吧.
        // 还是不太明白 orig_pte 干什么用的..
        pte_unmap_unlock(ptep, ptl);
        // pte_unmap_unlock do two things.
        // spin_unlock(ptl)
        // pte_unmap(pte) 
        //    x86-64 上 pte_unmap 啥也不干. it always has all page tables mapped.
        //    x86-32 上 kunmap_atomic(pte) .. 
        // 就 unmap 了 ?
    }
    // ...
    // 用 vma 的权限创建一个新 pte.
    entry = mk_pte(kpage, vma->vm_page_prot);
    if (is zero page, check pfn) {
        entry = pte_mkspecial(entry); // special flag, programmer def 的标记.
        zero_sharing++
            __inc_zone_page_state()
            dec_mm_counter(mm, MM_ANONPGAGE)
            // 三个都是统计用的.
    } else {
        get_page(kpage);    // 引用计数 +1
        page_add_anon_rmap(kpage, vma, addr) // 新的 pte 指向了这个 page. 反向映射.
    }
    set_pte_at_notify(mm, addr, ptep, entry); //  写上新的 entry
    page_remove_rmap(page); // 删掉 rmap
    // 这个 remove_rmap 也是有更新统计的吧.. 感觉这里也有问题.
    // TODO
    // remove_rmap 在 page 还有共享的情况下只是减少一个 _mapcount
    // 如果只有最后一个的话.
    //   也只是更新一下 zone 数据
    // 注释里写着 it would be tidy to reset the pageanon mapping here, but.. 呵呵
    if (!page_mapped(page))
        try_to_free_swap(page) // free 掉 swap cache. set page dirty 蛤???
    page_cache_release(page); // 就是 put_page.(宏) 不知道为什么用这个. 应该只是版本问题.
    pte_unmap_unlock(ptep, ptl);
}
```

咦 居然 pksm 和 ksm 不一样 ?
pksm 只是多了对 zero page 的处理.

Q: 如果被合并的 page 有多个映射到它的pte, 会怎么样?

A: rmap_walk 会遍历所有的映射到它的 vma, 每执行一次 replace_page 就删掉一个引用,
最后一次就能释放掉这个 page 了.

`cmp_and_merge_zero_page(page)` 之后:

``` c
kpage = stable_tree_search(page)
if (kpage) {
    err = try_to_merge_with_pksm_page(rmap_item, page, kpage);
    if (!err) {
        lock_page(kpage);
        // 下面这个是 ksm 的, 和 pksm 有点不一样.
        // 因为两者的 stable node 不一样.
        // stable_tree_append(rmap, page_stable_node(kpage))
        stable_tree_append(page_stable_rmap_item(kpage), page);
        //                      kpage->pksm( 就是 rmap )
        ...
    }
}
```

``` c
struct stable_node_anon {
    struct hlist_node hlist;
    struct anon_vma *anon_vma;
};

ksm page 的 rmap_item->hlist. 作为链表头, 后面跟着一串 stable_node_anon.
这个 rmap_item->hlist 有点浪费,  rmap_item->page 是 ksm page时才会用到.


static void stable_tree_append(struct rmap_item *rmap_head, struct page *page)
{
    // rmap_head 是 kpage 的 rmap_item.
    rmap = page->pksm;
    struct stable_node_anon *anon_node = alloc_stable_anon();
    if (PageKsm(page)) {
        // page 已经是 ksm page 了?
        //  TODO, 不可能吧.
        anon_node->anon_vma = rmap->anon_vma;
    } else
        anon_node->anon_vma = page_rmapping(page);

    get_anon_vma(anon_node->anon_vma) // 引用计数加一
    hlist_add_head(&anon_node->hlist, &rmap_head->hlist);
    if (!anon_node->hlist.next)
        ksm_pages_shared++;
        // 嗯, 合情合理
}
```

Q: 第一个 ksm page 是怎么产生的?

A: 等等再问, 反正不是这里. 后面有把正常 page变成 ksm page的.

继续

``` c
kpage = stable_tree_search(page)
if (kpage) {
    err = try_to_merge_with_pksm_page(rmap_item, page, kpage);
    if (!err) {
        lock_page(kpage);
        stable_tree_append(page_stable_rmap_item(kpage), page);
        //                      kpage->pksm( 就是 rmap )
        unlock_page(kpage);
    }
    put_page(kpage); // stable_tree_search 里面 get(get_ksm_page) 过.
    return error;
}

// 没在 stable tree 中找到.
tree_rmap_item = unstable_tree_search_insert(rmap_item, page, &tree_page);
// 这个函数, 在 unstable tree 里面找相等页, 如果没找到就插入.
// 找到则返回. 那个相应的 rmap.  get_mergeable_page 引用计数加一
// &tree_page 保存找到的那个在 unstable tree 里的 page.
// 如果 map_item 不在 unstable tree 中. 则插入 unstable tree
if (tree_rmap_item) {
    // 把两个页merge成一个页
    err = try_to_merge_two_pages(rmap_item, page, tree_rmap_item, tree_page);
    // page 变成 ksm page, 所有原来指向 tree_page 的 pte 指向 page.
    if (!err) {
	kpage = page;
	remove_rmap_item_from_tree(tree_rmap_item, 0);
	lock_page(kpage)
	err = stable_tree_insert(rmap_item, kpage);
	// 把kpage的rmap_item, 插入 stable tree.
	// kpage->mapping = rmap_item + flags.
	// rmap_item->address |= STABLE_FLAG
	if (!err) {
	    stable_tree_append(rmap_item, kpage);
	    // 给 kpage 分配一个 anon_node, 插到 rmap_item->hlist
	    lock_page(tree_page);
	    stable_tree_append(rmap_item, tree_page);
	    // 给 tree_page 分配一个 anon_node, 插到 rmap_item->hlist
	    unlock_page(tree_page);
	    err = 0;
	} else {
	    // insert to stable tree failed.
	    // TODO, 我觉得应该得有 else 吧.
	    /* try_to_merge_two_pages can return
	    * PKSM_FAULT_SUCCESS
	    * PKSM_FAULT_DROP
	    * PKSM_FAULT_TRY
	    * not properly handled by its caller
	    */

	}
	unlock(kpage)
    } else {
	// merge failed.
	// TODO error handling
    }
    put_page(tree_page); // ksm 比 pksm put_page(tree_page) 早.
}
```

再回头看一下 rmap 有什么问题. `rmap.c` 的 `rmap_walk()` 对
ksm page 调用 `rmap_walk_ksm(page, rwc)`;

``` c
// rmap_walk 的任务就是遍历所有相关的 vma
int rmap_walk_ksm(page, rwc) {
    // 看起来没什么问题.
    // search_new_forks 不太理解
}
```


``` c
static int try_to_merge_two_pages(rmap_item, page, tree_rmap_item, tree_page) {
    try_to_merge_with_pksm_page(rmap_item, page, NULL);
    // 第一次，NULL 表示把这个 page 设置为 ksm page.
    // 把所有指向这个 page 的 pte 写保护.
    try_to_merge_with_pksm_page(tree_rmap_item, tree_page, page);
    // 把所有指向 tree_page 的 pte 写保护.
    // 并指向上面的 page.
}

static int try_to_merge_with_pksm_page(rmap_item, page, kpage) {
    return try_to_merge_one_anon_page(page, kpage);
}

static int try_to_merge_one_anon_page(page, kpage); {
    if (page == kpage) return 0; // 不会合并同一页.
    if (!trylock_page(page)) return PKSM_FAULT_TRY;
    pksm_rmap_walk(page, pksm_wrprotect_pte, kpage);
    // 这里和 ksm 区别,  ksm 的一个 rmap_item 表示的一个虚拟页面,
    // 在合并是, 那一个虚拟地址的 pte 写保护
    // pksm 一个 rmap_item 表示一个物理页, 需要把所有映射到这个物理页的 pte 写保护.
    // 不理解的是, ksm 说 if it's mapped elsewhere, all of its ptes are 
    // necessarily already write-protected? : ???
    unlock_page(page);
}

static int pksm_wrprotect_pte(page, vma, addr, kpage) {
    if ((err = write_protect_page(vma, page, &orig_pte)) = 0) {
	if (!kpage) {
	    set_page_stable_ksm(page, NULL); // 嗯? setPageKsm 在哪? 哦, 
	    // ksm 不是 page flags 里面的一个bit.
	    // 是根据 page->mapping 来判断的.
	    mark_page_accessed(page); // ???
	} else if (pages_identical(page, kpage)) {
	    replace_page(vma, page, kpage, orig_pte)
	}
    }
    if ((vma->vm_flags & VM_LOCKED) && kpage && !err) {
	// VM_LOCKED, 是 mlock() 设置的. 大概, see mm/mlock.c
	// 把 page munlock, 把 kpage mlock.
	munlock_vma_page(page);
	if (!PageMlocked(page)) {
	    unlock_page(page);
	    lock_page(kpage);
	    mlock_vma_page(kpage); 
	    page = kpage; /// ??? 这波操作是干什么?
	}
    }
}
```

接下来看 pksm page 的 rmap_item 是怎么释放掉的.

通过 `pksm_del_anon_page(page)`, 在 `mm/page_alloc.c`,
见 [alloc_free_pages](alloc_free_pages.md).
这个函数标记 `rmap_item->address |= DELLIST_FLAG`. 加入 del_list.
pksmd 在运行中看到 DELLIST_FLAG, 然后释放.
del_list 感觉没什么必要, 可以删掉, 节省内存.

pksmd 在 `stable_tree_search()` 中, 检测 stable tree node 的 flag.
在 `stable_tree_insert()` 中, 检测 stable tree node 的 flag.
在 `unstable_tree_search_insert()` 中, 检测 unstable tree node 的flag.
在 `ksm_do_scan()` 中, (有个检测没有必要) 检测 new_list 中的 flag, 并
释放掉 del_list 中的所有 rmap_item.

不管怎样, 最后都是通过 `remove_rmap_item_from_tree(rmap_item)` 来释放
内存.


 

## unstable tree 扫描.

`ksm_do_scan()` 最后会扫描 unstable tree 的节点. 重新计算 checksum, 把checksum
发生变化的页面删除.

扫描每次都从 unstabletree_checksum_list 的表头开始, 是个问题.
TODO: 删掉 update_list, 在 unstable tree 中搜索时同步进行.


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

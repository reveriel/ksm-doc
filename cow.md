# cow

pksm cow?

先看一下 KSM 的 cow 是怎么样的. 以及 page_sharing 数据的统计.
再看 uksm 的cow.

note and idea:

- 可以不处理 shared page.
- 

## ksm's cow

ksm has a function `break_cow(rmap_item)`

``` c
static void break_cow(rmap_item)
{
    mm = rmap_itme->mm; // 如果是 pksm 里面的话 没有 ->mm,
                        // 需要使用反向映射找到所有 mm.
    put_anon_vma(rmap_item->anon_vma);
    down_read(&mm->mmap_sem);
    vma = find_mergeable_vma(mm, addr);
    if (vma)
    break_cow(mm, addr);
    up_read(&mm->mmap_sem);
}

// 我注释都看不懂!
static int break_ksm(vma, addr)
{
    do {
        cond_resched();
        page = follow_page(vma, addr, FOLL_GET);
        if (IS_ERR_OR_NULL(page))
            break;
	if (PageKsm(page))
            ret = handle_mm_fault(vma->vm_mm, vma, addr,
                                FAULT_FLAG_WRITE);
        else
            ret = VM_FAUlt_WRITE;
	put_page(page);
    } while (!(ret & (VM_FAULT_WRITE | VM_FAULT_SIGUS | VM_FAULT_OOM)));
    //// VM_FAULT_OOM ..
    return (ret & VM_FAULT_OOM) ? -ENOMEM : 0;
}
```

大致上就是 直接调用用 `handle_mm_fault()`, 触发 write fault. 这里 cow 操作是其他代码负责的.
while 循环, ret 结果是 VM_FAULT_* 的是某一种就停下.
如果 `handle_mm_fault()`成功是会返回0的, while 会再循环一次?

`break_cow()` 在下面这些情况下被调用:
- `try_to_merge_two_pages(rmap_item, page, tree_rmap_item, tree_page)`
  - 里面先把 page 变成 ksm page, 再把 tree_page 与之合并, 如果 tree_page 与之合并时出错,
    调用 break_cow, 把 page 还原. 但是错误也可能发生在 tree_page 被设置写保护之后,
    这种情况下却没有将 tree_page 也 break_cow. 
    我觉得不调用 `break_cow()` 也没问题. 设置写保护后, 进程写这个页面触发 page fault,
    会自动 cow 的.
- `cmp_and_merge_page(page, rmap_item)`
  - 最后, `try_to_merge_two_pages()` 成功了, 但是插入 stable tree,
    `stable_tree_insert(kpage)` 失败了 (这个失败也不好说啊..各种原因), 
    这时把 两个 page 都 `break_cow()`.

为什么 ksm 里面在 把一个 (rmap_item, page) 变成 ksm page 时, 没有使用反向映射,
遍历所有指向这个 page 的进程?

关键在于那句注释:
> if this anonymous page is mapped only here, its pte may need to be write-protected.
> If it's mapped elsewhere, all of its ptes are necessarily already write-protected.
匿名页被共享的话, 一定都是 write-protected. 可以这么认为吗? shared memory呢?
在 `ksm_madvice()` 中 如果 `vma->vm_flag` 是 `VM_SHARED`, 是不处理的, 所以 ksm
扫描的页面不包括 shared memory. 不是shared memory 不代表就不是被共享的啊.
fork 也会导致共享, 匿名页被共享据说是很常见的.

## ksm's pages_sharing

``` c
static void stable_tree_append(rmap_item, stable_node)
{
    hlist_add_head(&rmap_item->hlist, &stable_node->hlist);

    if (rmap_item->hlist.next)
        ksm_pages_sharing++;
    else
        ksm_pages_shared++;
}
```

``` c
static void remove_rmap_item_frome_tree(rmap_item)
{	
    // ...
    stable_node = rmap_item->head;  // 这里能从 rmap_item 找到 stable_node.
    if (stable_node->hlist.first)
        ksm_pages_sharing--;
    else
        ksm_pages_shared--;
}
```

此外, 还有`remove_node_from_stable_tree()`. 
``` c
void remove_node_from_stable_tree(stable_node) {
    hlist_for_each_entry(rmap_item, &stable_node->hlist, hlist) {
        if (rmap_item->hlist.next)
            ksm_pages_sharing--;
        else
            ksm_pages_sharing--;
    }
}
```

主要是在 `get_ksm_page()` 里面调用. 另外两处一个是 memory hotplug, 一个是 sysfs control
调用, 可以暂时不考虑.

在 `stable_tree_search(page)` 中, stable tree 的节点是 stable_node,
`tree_page = get_ksm_page(stable_node, lock_it:false)`.
`get_ksm_page()`这里会检测 mapping 是否变了.
``` c
expected_mapping = (void*)stable_node +(PAGE_MAPPING_ANON | PAGE_MAPPING_KSM);
if (ACCESS_ONCE(page->mapping) != expected_mapping)
    goto stale;
    
```
这函数.. 先不管 migration. 之前的版本是这样的:

``` c
/* get_ksm_page: checks if the page indicated by the stable node
 * is still its ksm page, despite having held no reference to it.
 * In which case we can trust the content of the page, and it
 * returns the gotten page; but if the page has now been zapped,
 * remove the stale node frome the stable tree and return NULL.
 *
 * You would expect the stable_node to hold a reference to the ksm page.
 * But if it increments the page's count, swapping out has to wait for
 * ksmd to come around again before it can free the page, which may take
 * seconds or even minutes: mouch too unresponsive. So instead we use a
 * "keyhole reference": access to the ksm page from the stable node peeps
 * out through its keyhole to see if that page still holds the right key,
 * pointing back to this stable node. This relies on freeing a PageAnon
 * page to reset its page->mapping to NULL, and relies on no other use of
 * a page to put something that might look like our key in page->mapping.
 *
 * include/linux/pagemap.h page_cache_get_speculative() is a good reference,
 * but this is different - made simpler by ksm_thread_mutex being held, but
 * interesting for assuming that no other use of the struct page could ever
 * put our expected_mapping into page->mapping (or a field of the union which
 * coincides with page->mapping). The RCU calls are not for KSM at all, but
 * to keep the page_count protocol described with page_cache_get_speculative.
 *
 * Note: it is possible that get_ksm_page() will return NULL one moment,
 * then page the next, if the page is in between page_freeze_refs() and
 * page_unfreeze_refs(): this shouldn't be a problem anywhere, the page
 * is on its way to being freed; but it is an anomaly to hear in mind.
 */
static struct page *get_ksm_page(stable_node) {
    page = stable_node->page;
    expected_mapping = (void *)stable_node + (PAGE_MAPPING_ANON | PAGE_MAPPING_KSM);
    rcu_read_lock();
    if (page->mapping != expected_mapping)
        goto stale;
    if (!get_page_unless_zero(page))
        goto stale;
    if (page->mapping != expected_mapping) {
        put_page(page):
	goto stale;
    }
    rcu_read_unlock();
    return page;
stale:
    rcu_read_unlock();
    remove_node_from_stable_tree(stable_node);
    return NULL;
}
```

在这个版本之前, stable_node 直接指向 ksm page, 并且增加了 page 的引用计数,
后来改成了这个 keyhole reference.

总之 ksm 在扫描 stable tree 时, 通过这样的方式来发现失效的 ksm page. 

do_wp_page() 里面, reuse page, 在 pageKsm 的情况是不会 reuse 的. 这怎么办? 我看错了?



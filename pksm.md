# pksm

## page 合并.





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

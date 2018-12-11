# rmap_item

this is about `struct rmap_item` in `mm/pksm.c`.

``` c
struct rmap_item {
    // points to the 'page's anon_vma
    struct anon_vma *anon_vma;
    // point to a anon page
    struct page *page;
    // only used as a flag
    // lower bits used for flags
    // can be removed
    unsigned long address;
    // new list
    struct list_head list;
    // del list
    struct list_head del_list;
    // list for stable anon
    struct hlist_head hlist;
    // node of unstable tree // and stable tree
    struct rb_node node;
    atomic_t _mapcount;
    // the page's checksum
    unsigned long checksum;
    // list for unstable page. all pages in unstable tree are in this list.
    struct list_head update_list;
    // cnt before cmp_and_merge
    int cnt;
}
```

``` c
struct page {
    // if page becomes a ksm page.
    //     page->mapping = rmap_item + (PAGE_MAPPING_ANON | PAGE_MAPPING_KSM)
    struct address_space *mapping;
    // if page is a pksm page
    //     page->pksm points to a rmap_item
}
```

``` c
struct stable_node_anon {
    struct hlist_node hlist;
    struct anon_vma *anon_vma;
}
```

nodes in stable tree are `rmap_item`s, the `->node` is used.

nodes in unstable tree are also `rmap_item`s, use `->node`.

stable and unstable trees:  red-black trees:

``` c
static struct rb_root root_stable_tree = RB_ROOT
static struct rb_root root_unstable_tree = RB_ROOT
```

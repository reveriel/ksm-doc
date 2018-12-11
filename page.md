# page


系统中的每个物理页都有一个 page to keep
track of whatever it is we are using the page for at the moment.

We have no way to track which tasks are using a page...

``` c
struct page  {}
```

in `linux/mmdebug.h`

``` c
void dump_page(page, reason);
```

count  是引用计数. 
那么 get page 时, 除了分配实际的物理页, 还要分配 struct page 咯(并不).
在 put page 里面, 如果 count = 0, 会释放页面, 释放的是 page 代表
的那个内存页面, 让它回到伙伴系统, 并不是是释放 struct page 本身.



`_mapcount` 是指有多少映射.


## get and put

一对 get 和 put. 这个是对 `struct page` 本身的引用计数.
不过在启动后还经常有 get put 操作, 让我不是很理解, pageinfo 不应该
在系统启动时就初始化, 一个物理页面一个, 放在一个数组里就行了么?


`linux/mm.h`:
``` c
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
extern bool __get_page_tail(page);

// methods to modify the page usage count.
// 哪些算是对 page 的使用:
//  - cache mapping (page->mapping)
//  - private data (page->private)
//  - page mapped in a task's page tables, each mapping is counted separately
// also, incresse the page count before critical routines in case pages gone.
static inline int put_page_testzero(page) {
    VM_BUG_ON_PAGE(atomic_read(&page->_count) == 0, page);
    return atomic_dec_and_test(&page->_count);
}
static inline int get_page_unless_zero(page) { return atomic_inc_not_zero(&page->_count); }
static inline int put_page_unless_one(page) { return atomic_add_unless(&page->_count,-1,1); }
```

`linux/mm.h`:
``` c
// setup the page count before being freed into the page allocator for
// the first time(boot or memory hotplug)
// 说明, pageinfo 刚创建后, set _count = 1, 然后 free 给 page allocator.
static inline void init_page_count(page) { atomic_set(&page->_count, 1); }
```

疑问 pageinfo 不应该是每个物理页一人一份, 在 boot 时初始化就行了吗, 为什么要free.

`linux/mm_types.h`
``` c
struct page {
//  ...
    struct {
        union {
            // count of ptes mapped in mms, to show when page is mapped and limit
            // reverse map searches
            // used also for tail pages refcounting instead of _count.
            // Tail pages cannot be mapped and keeping the tail page _count zero at
            // all times guaranttes
            atomic_t _mapcount;
        }
        atomic_t _count; // usage count
    }
}
```

`mm/swap.c`:

``` c
// 这个 put page
void put_page(struct page *page) {
    if (unlikey(PageCompound(page)))
        put_compound_page(page);
    else if (put_page_testzero(page)) // page->_count 减一, 如果等于 0 就 true.
        __put_single_page(page); // page->_count == 0 了!
}

static void __put_single_page(struct page *page)
{
    __page_cache_release(page);
    free_hot_cold_page(page, false); // free hot page
}
```



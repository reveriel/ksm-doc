# compound page.

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



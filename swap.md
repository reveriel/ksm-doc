# swap

`swap_state.c` 


**swap cache**


The Swap Cache

When swapping pages out to the swap files, Linux avoids writing pages if it does not have
to. There are times when a page is both in a **swap file** and in **physical memory**. This
happens when a page that was swapped out of memory was then brought back into memory when
it was again accessed by a process. So long as the page in memory is not written to, the
copy in the swap file remains valid.

Linux uses the swap cache to track these pages. **The swap cache is a list of page table
entries, one per physical page in the system**. This is a page table entry for a swapped out
page and describes which swap file the page is being held in together with its location in
the swap file. If a swap cache entry is non-zero, it represents a page which is being held
in a swap file that has not been modified. If the page is subsequently modified (by being
written to), its entry is removed from the swap cache.

When Linux needs to swap a physical page out to a swap file it consults the swap cache
and, if there is a valid entry for this page, it does not need to write the page out to
the swap file. This is because the page in memory has not been modified since it was last
read from the swap file.

The entries in the swap cache are page table entries for swapped out pages. They are
marked as invalid but contain information which allow Linux to find the right swap file
and the right page within that swap file.

[ref : linux tutorial](http://www.linux-tutorial.info/modules.php?name=MContent&pageid=314)

``` c
// allocate swap space for a page,
// @page we want to move to swap
// allocate swap space for the page and add the page to the
// swap cache.
int add_to_swap(struct page *page, struct list_head *list)

```

~
~

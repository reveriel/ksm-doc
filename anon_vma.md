##  anon_vma

guarded by rcu lock. ?

```
page->mapping;
```

`anon_vma  = page_lock_anon_vma_read(page)`


`mm/rmap.c`:

相关的几个数据结构:
``` c
struct vm_area_struct {
    unsigned long vm_start; // start address within vm_mm
    unsigned long vm_end;
    struct list_head anon_vma_chain;
    struct anon_vma *anon_vma;
}

```

``` c
// getting a lock on a stable anon_vma from a page off the LRU is tricky
// there is no serialization against page_remove_rmap().
// the best this function can do is return a locked anon_vma that might
// have been 
struct anon_vma *page_get_anon_vma(page) {

}
struct anon_vma *page_lock_anon_vma_read(page) {

}
```




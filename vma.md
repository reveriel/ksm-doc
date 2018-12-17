# vma

``` c
struct vm_area_struct {
    // vma 表示一段虚拟地址.
    unsigned long vm_start;
    unsigned long vm_end;
    // 按地址排序的 vma 链, 相邻 vma 是可以合并的.
    struct vm_area_struct *vm_next, *vm_prev;
    // 红黑树, 方便查找.
    struct rb_node vm_rb;
    // 此 vma 左边最大的空闲地址块的大小.
    unsigned long rb_subtree_gap;
    // 属于的 mm
    struct mm_struct *vm_mm;
    pgprot_t vm_page_prot;
    unsigned long vm_flags
    // linear or nonlinear
    union {
	struct {
	    struct rb_node rb;
	    unsigned long rb_subtree_last;
	} linear;
	struct list_head nonlinear;
    } shared;

    struct list_head anon_vma_chain;
    struct anon_vma *anon_vma;// serialized by ... 什么意思
    const struct vm_operations_struct *vm_ops;
    unsigned long vm_pgoff; // offset within vm_file
    struct file *vm_file; // file we map to (can be NULL)   
    void *vm_private_data
}

/*
* A file's MAP_PRIVATE vma can be in both i_mmap tree and anon_vma
* list, after a COW of one of the file pages.  A MAP_SHARED vma
* can only be in the i_mmap tree.  An anonymous MAP_PRIVATE, stack
* or brk vma (with NULL file) can only be in an anon_vma list.  */
```


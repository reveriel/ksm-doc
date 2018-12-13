# rmap

反向映射.

页面 swap 时, 需要断开所有指向这个页面的 pte.
需要数据结构支持从 page 找到所有指向 page 的 pte.
如果 直接在 page 里弄一个链表, 链表元素指向各个 pte. 费空间.
如果遍历 每个进程的 页表, 费时.

匿名页的情况:

page -> anon_vma -> (related) vma -> mm -> page table



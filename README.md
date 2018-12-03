# KSM

KSM(Kernel Samepage Merging). Try to improve it. Based on
[PKSM](code.google.com/archive/p/pksm). Kernel v3.18-rc7

## Possible plans

* delay, 延迟去重..
* hash adjustable. 尝试调整部分哈希的强度. 来自 UKSM
* hash table instead of rbtree. 将红黑树改为哈希表.
* test UKSM, 移植 UKSM.
* same virtual address, 合并相同虚拟地址的页面.
* page cache, Page Cache 中是否有去重的潜力.

## Background

[KSM](ksm.md)



## Plans

### delay

[delay](delay.md)

### adaptive partial hash

[aph](aph.md)

## Others

### COW

``` c
    struct BookKeeper *bk = BookKeeper_init();
    alloc_pages_write(bk, 100, 1);
    sleep(10);

    pid_t pid = fork();
    int r;
    if (pid == 0) {
            write_pages(bk, 100, 2);
            sleep(10);
    } else {
            wait(&r);
    }

    free_all_pages(bk);
```
期望结果是, 子进程 `write_pages()` 导致 COW, 产生新的页面, 
这些页面再次被合并, sharing 增加 100, 实际上, 没有增加.
可能原因: 

这个结果和之前在 手机上测的不一致, 手机上 fork 后, sharing 增加了.


``` c
    struct BookKeeper *bk = BookKeeper_init();
    alloc_pages_write(bk, 100, 1);
    sleep(10);

    pid_t pid = fork();
    int r;
    if (pid == 0) {
            write_pages(bk, 100, 2);
            sleep(10);
    } else {
            write_pages(bk, 100, 3);
            wait(&r);
    }

    free_all_pages(bk);
```
期望结果, write_pages() 会导致 COW,  sharing 减少 100, 然后增加 200,
实际结果, 在 write_pages() 后, sharing 减少 100.


这个程序移到手机上测一测?



[如何使用 email 收发 patch](./email.md)



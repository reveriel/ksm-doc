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

### 

## Others

[如何使用 email 收发 patch](./email.md)

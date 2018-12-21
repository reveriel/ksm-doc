
### adaptive partial hash

在 byte-by-byte 比较两个页面是否相等之前.
有 

hash_cmp  == 0 的次数 M,
memcmp_pages  == 0 的次数 N.
memcmp_pages == 0, 则一定 hash_cmp == 0, 反之不然.

只有 hash_cmp == 0 的情况下才会调用 memcmp_pages, 
所以 `N < = M`,  N/M \in [0, 1]

如果 hash 强度很高, 强到和 memcmp 一样 (当然这是不可能的, 因为hash 空间小于 page 空间),
hash_cmp == 0 就 意味着 memcmp == 0, N/M 趋近于 1.
如果 hash 很弱, N/M 趋近于 0.



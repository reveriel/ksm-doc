# kind

``` c
enum blk_throtl_type {
    BLK_THROTL_TA,  // top app
    BLK_THROTL_FG,  // foreground
    BLK_THROTL_KBG,  // key background
    BLK_THROTL_SBG,  // system background
    BLK_THROTL_BG,
    BLK_THROTL_TYPE_NR,
}
```


how many pages belongs to which kinds?

a counter. 
each kinds has its cow rate.

timer. how long does it take to 
- merge two page
  - success
  - fail
- unmerge / cow

but first, fully understand is required.



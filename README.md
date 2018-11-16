# KSM

KSM(Kernel Samepage Merging). Try to improve it. Based on
[PKSM](code.google.com/archive/p/pksm).  Kernel v3.18-rc7

see document [ksm-doc](ksm-doc/)

[TOC]

## Possible plans

- delay
- hash adjustable.
- test uksm
- hash table instead of rbtree
- same virtual address
- page cache

## Background
### BG: KSM

KSM, corresponding file [`ksm.c`](mm/ksm.c), merges pages with same contents.
KSM is enabled by setting `CONFIG_KSM=y`. It can saves a lot of memory in
Virutal Machine Hypervisors.

You can mark a pieces of memory as "Mergeable" using syscall `madvice`, then
there is a kthread `[ksmd]` that scan all anonymous pages in the Mergeable
memory area. When found two pages equal, `ksmd` sets two pages sharing one
physical page by using COW(Copy on Write) mechanism.

The main data struct is two red-black tree used to find equal pages. Just
like we when we want to find repeating numbers in a large array, sort it or
insert to a hashtable are the two most obvious way.

VMware uses the hashtable method in its Virtual Machine products, and has a
patent claim its intellectual property. So Linux community pick the other
way --- sort the array.

> Note: Sort a constantly changing array

The problem is that pages are constantly changing. We need to sort a
changing array.

Those numbers(or pages) that won't settle, changing very fast, are not
good candidates for sharing. Sharing them would soon get a COW break.
Gone are the sharing and the wasted CPU cycles.

So KSM uses two red-black trees, the 'unstable' tree, and the 'stable' tree.
Those who haven't changed for a while, are considered good candidate, are put
into the unstable tree. Note this is a red-black tree. The changing of
pages will gradually turn it out of order. So the unstable tree is emptied
every some time.

> TODO: find out how does KSM empty the unstable tree.

The stable tree lives those who are merged to a read only page. They won't
change, so the stable tree is always in order.

See `mm/ksm.c:cmp_and_merge_page()`
```
When `ksmd` inspect an anonymous page,
First search it in the stable tree.
if found:
  merge the page
else, no found:
  has the page changed since 'ksmd' last saw him?
  if yes, changed:
     out, I don't think our sharing service is suitable for you
  eles, no changed:
     put you in the unstable tree.
     maybe you can find someone equal to you
     if found an equal page here
        you both move to the stable tree.
```

Basically, that's all.

### BG, PKSM

PKSM (file [`mm/pksm.c`](mm/pksm.c)) made some changes to the original KSM.

It has three queues as worklists.
- new anon page list, or new list.
  - every new anon page is added to this list.
- rescan anon page list, or rescan list.
  - pages that failed to merge, or removed from unstable tree
- delete anon page list, or del list.

Every anonymous pages born into the world(system) are put in the new list.
Those who failed during merge were added to the rescan list.
ksmd(or pksmd) also scans the unstable tree and picks up those who's content
has changed, adds them to the rescan list.

The candidate to be to put to the test of `cmp_and_merge_page()` are
half from new list, half from rescan list.

The del list is just for the convenience of release the data structure for
each anonymous page. Every processes in the system may allocate new
anonymous pages and release them. When releasing, the corresponding
data structure is simply marked and leave the actual deallocation to ksmd.

Pksm also has a special zero page, every anonymous page is first tried to
merge with this. Empirically zero pages are more than others.

And, when deciding if two pages are equal, the partial hash values are
compared first. A byte-by-byte comparison is done only when partial hash
values are the same.

I think that's all of PKSM. Quite short, isn't it.

## Possible Plans

- delay
- hash adjustable.
- test uksm
- hash table instead of rbtree
- same virtual address
- page cache

### PP: Delay

"Every new page is added to the new list." Is there any problem?

Also, every page is first search in the stable tree. That doesn't
sound good. A new-born page may change very soon. Normally We allocate
memory not for fun, but to put data in it. New page may not be a
promising candidate for sharing.

Possible solution: 
**Watch Window**, pages should stay here for a while, if a 

> What to try asciiDoc ...







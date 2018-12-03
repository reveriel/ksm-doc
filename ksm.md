
### BG: KSM

KSM, corresponding file `mm/ksm.c`, merges pages with same
contents. KSM is enabled by setting `CONFIG_KSM=y`. It can saves a lot
of memory in Virutal Machine Hypervisors.

You can mark a pieces of memory as "Mergeable" using syscall
`madvice`, then there is a kthread `[ksmd]` that scan all anonymous
pages in the Mergeable memory area. When found two pages equal, `ksmd`
sets two pages sharing one physical page by using COW(Copy on Write)
mechanism.

The main data struct is two red-black tree used to find equal pages.
Just like we when we want to find repeating numbers in a large array,
sort it or insert to a hashtable are the two most obvious way.

VMware uses the hashtable method in its Virtual Machine products, and
has a patent claim its intellectual property. So Linux community pick
the other way — sort the array.

NOTE: Sort a constantly changing array

The problem is that pages are constantly changing. We need to sort a
changing array.

Those numbers(or pages) that won’t settle, changing very fast, are not
good candidates for sharing. Sharing them would soon get a COW break.
Gone are the sharing and the wasted CPU cycles.

So KSM uses two red-black trees, the `unstable' tree, and the `stable'
tree. Those who haven’t changed for a while, are considered good
candidate, are put into the unstable tree. Note this is a red-black
tree. The changing of pages will gradually turn it out of order. So the
unstable tree is emptied every some time.

TODO: find out how does KSM empty the unstable tree.

The stable tree lives those who are merged to a read only page. They
won’t change, so the stable tree is always in order.

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

Basically, that’s all.



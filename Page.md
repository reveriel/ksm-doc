### Page table

[Page Table Management](https://www.kernel.org/doc/gorman/html/understand/understand006.html)

Each process has a pointer `mm_struct->pgd` points to its own __Page Global
Directory(PGD)__ which is a physical page frame. The frame contains an array
of type `pgd_t` which is an architecture specific type defined in `<asm/page.h>`

PGD -> __Page Middle Directory(PMD)__ -> __Page Table Entries(PTE)__

pte points to page frames.

When swap out, the swap entry is stored in the PTE and used by
`mm/memory.c:do_swap_page()`

There are some bits about each page. 

see `arch/xx/include/asm/pgtable.h`

protection:

The read permissions for an entry are tested with pte_read(), set with pte_mkread() and
cleared with pte_rdprotect();
The write permissions are tested with pte_write(), set with pte_mkwrite() and cleared with
pte_wrprotect();
The execute permissions are tested with pte_exec(), set with pte_mkexec() and cleared with
pte_exprotect(). It is worth nothing that with the x86 architecture, there is no means of
setting execute permissions on pages so these three macros act the same way as the read
macros;
The permissions can be modified to a new value with pte_modify() but its use is almost
non-existent. It is only used in the function change_pte_range() in mm/mprotect.c.

state:

The fourth set of macros examine and set the state of an entry. There are only two bits
that are important in Linux, the dirty bit and the accessed bit. To check these bits, the
macros pte_dirty() and pte_young() macros are used. To set the bits, the macros
pte_mkdirty() and pte_mkyoung() are used. To clear them, the macros pte_mkclean() and
pte_old() are available.


The macro `mk_pte()` takes a `struct page` and protection bits and combines them together to
form the `pte_t` that needs to be inserted into the page table. A similar macro
`mk_pte_phys()` exists which takes a physical page address as a parameter.


The macro `pte_page()` returns the `struct page` which corresponds to the PTE entry.
`pmd_page()` returns the `struct page` containing the set of PTEs.


Code in x86:

``` c
#define pte_page(pte)	pfn_to_page(pte_pfn(pte))
```

``` c
static inline unsigned long pte_pfn(pte_t pte)
{
	return (pte_val(pte) & PTE_PFN_MASK) >> PAGE_SHIFT;
}
```

seciton ?

`struct mem_section`, is, logically, a pointer to an array of struct pages.

``` c
#define pfn_to_page __pfn_to_page
#define __pfn_to_page(pfn)                              \
({      unsigned long __pfn = (pfn);                    \
	struct mem_section *__sec = __pfn_to_section(__pfn);    \
	__section_mem_map_addr(__sec) + __pfn;          \
})

static inline struct mem_section *__pfn_to_section(unsigned long pfn)
{
	return __nr_to_section(pfn_to_section_nr(pfn));
}

#define pfn_to_section_nr(pfn) ((pfn) >> PFN_SECTION_SHIFT)
#define section_nr_to_pfn(sec) ((sec) << PFN_SECTION_SHIFT)

static inline struct page *__section_mem_map_addr(struct mem_section *section)
{
	unsigned long map = section->section_mem_map;
	map &= SECTION_MAP_MASK;
	return (struct page *)map;
}
```

QUESTION: `pte_dirty()` and `PageDirty()`, diff?

relation between `pte` and `struct page` ?





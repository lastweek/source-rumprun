#! /usr/bin/env awk -f

# build page tables.  easier doing it like this than in assembly.
# we might actually want the page tables to reflect reality some
# day (e.g. mapping text r/o), but for now we don't care.

BEGIN {
	MAXGIGS=512
	MINGIGS=4

	if (mapgigs == 0)
		mapgigs = MINGIGS
	if (mapgigs < MINGIGS) {
		printf("currently need min 4G for mmio space, you want %d\n", \
		    MINGIGS, mapgigs) | "cat 1>&2";
		exit(1);
	}
	if (mapgigs > MAXGIGS) {
		printf("up to %dG supported, you have %d\n", \
		    MAXGIGS, mapgigs) | "cat 1>&2";
		exit(1);
	}

	PG_VALID = 0x001
	PG_RW	 = 0x002
	PG_PS	 = 0x080
	PG_GLOBAL= 0x100
	PG_FORALL= PG_VALID + PG_RW;

	TWOMEGS	 = 0x200000

	printf("/* AUTOMATICALLY GENERATED BY makepagetables.awk */\n\n");

	# first level, only used for lowest 2MB, with 0 unmapped
	printf(".align 0x1000\ncpu_pt0:\n");
	printf("\t.quad 0x0\n");
	addr = 0x1000
	for (i = 0; i < 0x1ff; i++) {
		printf("\t.quad 0x%x + 0x%x\n", addr, PG_FORALL);
		addr += 0x1000
	}

	# second level, page directories, need full one per gig
	for (i = 0; i < mapgigs; i++) {
		printf("\n.align 0x1000\ncpu_pd%d:\n", i);
		addr = i*512*TWOMEGS
		if (i == 0) {
			printf("\t.quad cpu_pt0 + 0%x\n", PG_FORALL);
			j = 1
			addr += TWOMEGS
		} else {
			j = 0
		}
		for (; j < 0x200; j++) {
			printf("\t.quad 0x%016x + 0x%x + 0x%x\n", \
			    addr, PG_FORALL, PG_PS);
			addr += TWOMEGS
		}
	}

	# third level, page directory pointer tables, need only one for now
	printf("\n.align 0x1000\ncpu_pdpt:\n");
	for (i = 0; i < mapgigs; i++) {
		printf("\t.quad cpu_pd%d + 0x%x\n", i, PG_FORALL);
	}
	if (mapgigs != MAXGIGS) {
		printf("\t.fill 0x%x, 0x8, 0x0\n", MAXGIGS-mapgigs);
	}

	# and finally, lessons in hate from page map level 42
	printf("\n.align 0x1000\ncpu_pml4:\n");
	printf("\t.quad cpu_pdpt + 0x%x\n", PG_FORALL);
	printf("\t.fill 0x1ff, 0x8, 0x0\n");
}

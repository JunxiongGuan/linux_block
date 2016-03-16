/*
 *  Copyright (C) 2011 Texas Instruments Incorporated
 *  Author: Mark Salter <msalter@redhat.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License version 2 as
 *  published by the Free Software Foundation.
 */
#include <linux/module.h>
#include <linux/dma-mapping.h>
#include <linux/mm.h>
#include <linux/mm_types.h>
#include <linux/scatterlist.h>

#include <asm/cacheflush.h>

static void c6x_dma_sync(dma_addr_t handle, size_t size,
			 enum dma_data_direction dir)
{
	unsigned long paddr = handle;

	BUG_ON(!valid_dma_direction(dir));

	switch (dir) {
	case DMA_FROM_DEVICE:
		L2_cache_block_invalidate(paddr, paddr + size);
		break;
	case DMA_TO_DEVICE:
		L2_cache_block_writeback(paddr, paddr + size);
		break;
	case DMA_BIDIRECTIONAL:
		L2_cache_block_writeback_invalidate(paddr, paddr + size);
		break;
	default:
		break;
	}
}

static dma_addr_t c6x_dma_map_page(struct device *dev, struct page *page,
		unsigned long offset, size_t size, enum dma_data_direction dir,
		struct dma_attrs *attrs)
{
	dma_addr_t handle = virt_to_phys(page_address(page) + offset);

	c6x_dma_sync(handle, size, dir);
	return handle;
}

static void c6x_dma_unmap_page(struct device *dev, dma_addr_t handle,
		size_t size, enum dma_data_direction dir, struct dma_attrs *attrs)
{
	c6x_dma_sync(handle, size, dir);
}

static void c6x_dma_sync_single_for_cpu(struct device *dev, dma_addr_t handle,
		size_t size, enum dma_data_direction dir)
{
	c6x_dma_sync(handle, size, dir);

}

static void c6x_dma_sync_single_for_device(struct device *dev,
		dma_addr_t handle, size_t size, enum dma_data_direction dir)
{
	c6x_dma_sync(handle, size, dir);

}

struct dma_map_ops c6x_dma_ops = {
	.alloc			= c6x_dma_alloc,
	.free			= c6x_dma_free,
	.map_page		= c6x_dma_map_page,
	.unmap_page		= c6x_dma_unmap_page,
	.sync_single_for_device	= c6x_dma_sync_single_for_device,
	.sync_single_for_cpu	= c6x_dma_sync_single_for_cpu,
};
EXPORT_SYMBOL(c6x_dma_ops);

/* Number of entries preallocated for DMA-API debugging */
#define PREALLOC_DMA_DEBUG_ENTRIES (1 << 16)

static int __init dma_init(void)
{
	dma_debug_init(PREALLOC_DMA_DEBUG_ENTRIES);

	return 0;
}
fs_initcall(dma_init);

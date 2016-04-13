/*
 * PCI IRQ handing code
 *
 * Copyright (c) 2008 James Bottomley <James.Bottomley@HansenPartnership.com>
 * Copyright (c) 2016 Christoph Hellwig.
 */

#include <linux/acpi.h>
#include <linux/device.h>
#include <linux/kernel.h>
#include <linux/export.h>
#include <linux/pci.h>
#include <linux/interrupt.h>
#include "pci.h"

static int pci_nr_irq_vectors(struct pci_dev *pdev)
{
	int nr_entries;

	nr_entries = pci_msix_vec_count(pdev);
	if (nr_entries <= 0 && pci_msi_supported(pdev, 1))
		nr_entries = pci_msi_vec_count(pdev);
	if (nr_entries <= 0)
		nr_entries = 1;
	return nr_entries;
}

static int pci_enable_msix_range_wrapper(struct pci_dev *pdev, u32 *irqs,
		int nr_vecs)
{
	struct msix_entry *msix_entries;
	int vecs, i;

	msix_entries = kcalloc(nr_vecs, sizeof(struct msix_entry), GFP_KERNEL);
	if (!msix_entries)
		return -ENOMEM;

	for (i = 0; i < nr_vecs; i++)
		msix_entries[i].entry = i;

	vecs = pci_enable_msix_range(pdev, msix_entries, 1, nr_vecs);
	if (vecs > 0) {
		for (i = 0; i < vecs; i++)
			irqs[i] = msix_entries[i].vector;
	}

	kfree(msix_entries);
	return vecs;
}

int pci_alloc_irq_vectors(struct pci_dev *pdev, int nr_vecs)
{
	int vecs, ret, i;
	u32 *irqs;

	nr_vecs = min(nr_vecs, pci_nr_irq_vectors(pdev));

	irqs = kcalloc(nr_vecs, sizeof(u32), GFP_KERNEL);
	if (!irqs)
		return -ENOMEM;

	vecs = pci_enable_msix_range_wrapper(pdev, irqs, nr_vecs);
	if (vecs <= 0) {
		vecs = pci_enable_msi_range(pdev, 1, min(nr_vecs, 32));
		if (vecs <= 0) {
			ret = -EIO;
			if (!pdev->irq)
				goto out_free_irqs;

			/* use legacy irq */
			vecs = 1;
		}

		for (i = 0; i < vecs; i++)
			irqs[i] = pdev->irq + i;
	}

	pdev->irqs = irqs;
	return vecs;

out_free_irqs:
	kfree(irqs);
	return ret;
}
EXPORT_SYMBOL(pci_alloc_irq_vectors);

void pci_free_irq_vectors(struct pci_dev *pdev)
{
	if (pdev->msi_enabled)
		pci_disable_msi(pdev);
	else if (pdev->msix_enabled)
		pci_disable_msix(pdev);

	kfree(pdev->dev.irq_affinity);
	pdev->dev.irq_affinity = NULL;
	kfree(pdev->irqs);
}
EXPORT_SYMBOL(pci_free_irq_vectors);

static void pci_note_irq_problem(struct pci_dev *pdev, const char *reason)
{
	struct pci_dev *parent = to_pci_dev(pdev->dev.parent);

	dev_err(&pdev->dev,
		"Potentially misrouted IRQ (Bridge %s %04x:%04x)\n",
		dev_name(&parent->dev), parent->vendor, parent->device);
	dev_err(&pdev->dev, "%s\n", reason);
	dev_err(&pdev->dev, "Please report to linux-kernel@vger.kernel.org\n");
	WARN_ON(1);
}

/**
 * pci_lost_interrupt - reports a lost PCI interrupt
 * @pdev:	device whose interrupt is lost
 *
 * The primary function of this routine is to report a lost interrupt
 * in a standard way which users can recognise (instead of blaming the
 * driver).
 *
 * Returns:
 *  a suggestion for fixing it (although the driver is not required to
 * act on this).
 */
enum pci_lost_interrupt_reason pci_lost_interrupt(struct pci_dev *pdev)
{
	if (pdev->msi_enabled || pdev->msix_enabled) {
		enum pci_lost_interrupt_reason ret;

		if (pdev->msix_enabled) {
			pci_note_irq_problem(pdev, "MSIX routing failure");
			ret = PCI_LOST_IRQ_DISABLE_MSIX;
		} else {
			pci_note_irq_problem(pdev, "MSI routing failure");
			ret = PCI_LOST_IRQ_DISABLE_MSI;
		}
		return ret;
	}
#ifdef CONFIG_ACPI
	if (!(acpi_disabled || acpi_noirq)) {
		pci_note_irq_problem(pdev, "Potential ACPI misrouting please reboot with acpi=noirq");
		/* currently no way to fix acpi on the fly */
		return PCI_LOST_IRQ_DISABLE_ACPI;
	}
#endif
	pci_note_irq_problem(pdev, "unknown cause (not MSI or ACPI)");
	return PCI_LOST_IRQ_NO_INFORMATION;
}
EXPORT_SYMBOL(pci_lost_interrupt);
